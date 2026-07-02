import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service WebSocket natif — compatible avec Laravel Reverb
/// Remplace pusher_channels_flutter (incompatible AGP 8.11+)
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static const String _host  = 'api.vigiroutes.com';
  static const String _appKey= '642e796713cd4093e508862ee725e601';
  static const int    _port  = 443;

  WebSocketChannel? _channel;
  String?           _token;
  bool              _connected = false;
  Timer?            _pingTimer;
  Timer?            _reconnectTimer;

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
      // exception non rattrapée jusqu'au gestionnaire d'erreur global de
      // l'app (même bug identifié et corrigé côté vigiroutesPro).
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

      // Connexion établie
      if (event == 'pusher:connection_established') {
        debugPrint('[WS] Handshake Reverb OK');
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

  void _subscribeChannel(String channel) {
    // Auth pour les canaux privés
    _send({
      'event': 'pusher:subscribe',
      'data': {
        'channel': channel,
        'auth':    '', // Reverb génère l'auth côté serveur
      },
    });
  }

  Stream<Map<String,dynamic>> subscribeToIntervention(String userId) =>
      _subscribe('private-user.$userId', 'intervention.updated');

  Stream<Map<String,dynamic>> subscribeToDispatch(String providerId) =>
      _subscribe('private-provider.$providerId', 'intervention.updated');

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
