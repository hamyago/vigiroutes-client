import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service WebSocket natif — compatible avec Laravel Reverb
/// Remplace pusher_channels_flutter (incompatible AGP 8.11+)
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static const String _host      = 'api.vigiroutes.com';
  static const String _appKey    = '642e796713cd4093e508862ee725e601';
  static const int    _port      = 443;
  // BUG CORRIGÉ : cette app est un CLIENT — l'auth des canaux privés doit
  // passer par le groupe de routes 'user' (middleware firebase.user), pas
  // 'provider'. Sinon $request->user() ne résout pas le bon modèle et
  // routes/channels.php refuse l'abonnement.
  static const String _authUrl   = 'https://$_host/api/user/broadcasting/auth';

  WebSocketChannel? _channel;
  String?           _token;
  String?           _socketId;
  bool              _connected = false;
  Timer?            _pingTimer;
  Timer?            _reconnectTimer;
  final Dio         _authDio = Dio();

  final Map<String, StreamController<Map<String,dynamic>>> _controllers = {};
  final Map<String, Set<String>> _subscriptions = {}; // channel → events

  bool get isConnected => _connected;

  // ── Connexion ──────────────────────────────────────────────────────────────

  Future<void> init(String sanctumToken) async {
    _token = sanctumToken;
    await _connect();
  }

  Future<void> _connect() async {
    try {
      final uri = Uri.parse(
        'wss://$_host:$_port/app/$_appKey'
        '?protocol=7&client=dart&version=1.0&flash=false',
      );

      _channel = WebSocketChannel.connect(uri);

      // BUG CORRIGÉ : WebSocketChannel.connect() ne lève PAS l'échec de
      // connexion (DNS, hôte injoignable, etc.) de façon fiable via
      // stream.listen(onError: ...) — problème connu du package. Sans ce
      // `await ... .ready`, une simple coupure réseau/DNS remontait comme
      // exception non rattrapée jusqu'au gestionnaire d'erreur global.
      await _channel!.ready;

      _connected = true;

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
      );

      // Ping toutes les 30s pour garder la connexion vivante
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());

      debugPrint('[WS] Connecté à Reverb');
    } catch (e) {
      debugPrint('[WS] Erreur connexion : $e');
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg  = jsonDecode(raw as String) as Map<String, dynamic>;
      final event= msg['event'] as String? ?? '';
      final chan  = msg['channel'] as String? ?? '';

      // Répondre au ping Pusher
      if (event == 'pusher:ping') {
        _send({'event': 'pusher:pong', 'data': {}});
        return;
      }

      // Connexion établie — récupérer le socket_id, indispensable pour
      // authentifier ensuite les canaux privés (BUG CORRIGÉ : jamais
      // capturé avant, donc l'auth des canaux privés était impossible
      // même une fois la signature du serveur obtenue).
      if (event == 'pusher:connection_established') {
        try {
          final data = msg['data'];
          final parsed = data is String
              ? jsonDecode(data) as Map<String, dynamic>
              : Map<String, dynamic>.from(data as Map);
          _socketId = parsed['socket_id'] as String?;
        } catch (e) {
          debugPrint('[WS] Impossible de lire le socket_id: $e');
        }
        debugPrint('[WS] Handshake Reverb OK (socket_id=$_socketId)');
        // Re-souscrire aux canaux actifs après reconnexion
        for (final channel in _subscriptions.keys) {
          _subscribeChannel(channel);
        }
        return;
      }

      // Diffuser aux controllers abonnés
      final key = '$chan:$event';
      if (_controllers.containsKey(key)) {
        final data = msg['data'];
        Map<String,dynamic> parsed;
        if (data is String) {
          parsed = jsonDecode(data) as Map<String,dynamic>;
        } else if (data is Map) {
          parsed = Map<String,dynamic>.from(data);
        } else {
          parsed = {};
        }
        _controllers[key]!.add(parsed);
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WS] Erreur: $error');
    _connected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connexion fermée');
    _connected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      debugPrint('[WS] Reconnexion...');
      await _connect();
    });
  }

  void _ping() {
    _send({'event': 'pusher:ping', 'data': {}});
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  // ── Souscription aux canaux privés ─────────────────────────────────────────

  /// BUG CORRIGÉ : envoyait 'auth': '' (chaîne vide) en supposant que
  /// Reverb générait l'authentification côté serveur automatiquement —
  /// faux. Pour un canal privé, c'est le CLIENT qui doit demander une
  /// signature au serveur (POST /broadcasting/auth avec channel_name +
  /// socket_id + le token Firebase), signature que Reverb vérifie avant
  /// d'accepter l'abonnement. Sans ça, Reverb rejette silencieusement
  /// tout abonnement à un canal privé — aucune mise à jour temps réel
  /// (statut, position du prestataire) n'a jamais pu arriver.
  Future<void> _subscribeChannel(String channel) async {
    if (!channel.startsWith('private-')) {
      _send({'event': 'pusher:subscribe', 'data': {'channel': channel}});
      return;
    }

    if (_socketId == null) {
      debugPrint('[WS] Abonnement à $channel différé (socket_id pas encore prêt)');
      return;
    }

    // BUG CORRIGÉ : utilisait _token, un jeton Firebase figé au moment du
    // login (jamais rafraîchi ensuite) — les jetons Firebase expirent au
    // bout d'1h. Confirmé via les logs nginx côté serveur : requêtes
    // /broadcasting/auth bien envoyées mais rejetées en 401. Même
    // principe que ApiService (qui redemande un jeton frais à chaque
    // requête) appliqué ici.
    String? freshToken;
    try {
      freshToken = await firebase_auth.FirebaseAuth.instance.currentUser
          ?.getIdToken(false);
    } catch (e) {
      debugPrint('[WS] Impossible de rafraîchir le jeton Firebase : $e');
    }
    freshToken ??= _token;
    if (freshToken == null) {
      debugPrint('[WS] Abonnement à $channel différé (aucun jeton disponible)');
      return;
    }

    try {
      final response = await _authDio.post(
        _authUrl,
        data: {
          'socket_id':    _socketId,
          'channel_name': channel,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $freshToken'},
          contentType: 'application/json',
        ),
      );
      final auth = response.data['auth'] as String?;
      if (auth == null) {
        debugPrint('[WS] Auth vide reçue pour $channel');
        return;
      }
      _send({
        'event': 'pusher:subscribe',
        'data': {
          'channel': channel,
          'auth':    auth,
        },
      });
      debugPrint('[WS] Abonné à $channel');
    } catch (e) {
      debugPrint('[WS] Échec auth canal $channel : $e');
    }
  }

  Stream<Map<String,dynamic>> subscribeToIntervention(String userId) =>
      _subscribe('private-user.$userId', 'intervention.updated');

  Stream<Map<String,dynamic>> subscribeToAdminInterventions() =>
      _subscribe('private-admin.interventions', 'intervention.updated');

  Stream<Map<String,dynamic>> subscribeToEmergencies() =>
      _subscribe('private-admin.interventions', 'emergency.created');

  Stream<Map<String,dynamic>> _subscribe(String channel, String event) {
    final key = '$channel:$event';

    if (!_controllers.containsKey(key)) {
      _controllers[key] = StreamController<Map<String,dynamic>>.broadcast();
      _subscriptions.putIfAbsent(channel, () => {}).add(event);
      if (_connected) _subscribeChannel(channel);
    }

    return _controllers[key]!.stream;
  }

  // ── Déconnexion ────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
    _subscriptions.clear();
    _connected = false;
    debugPrint('[WS] Déconnecté');
  }
}
