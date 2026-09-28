// lib/core/services/realtime_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Service WebSocket natif — compatible avec Laravel Reverb.
//
// ⚠️ AUTH : on utilise UNIQUEMENT le token Sanctum (voir ApiService).
// L'app n'utilise plus Firebase Auth (remplacé par Termii OTP + Sanctum).
//
// ⚠️ CONTRAT BACKEND :
//   - Endpoint : POST /api/user/broadcasting/auth
//   - Header   : Authorization: Bearer <sanctum_token>
//   - Body     : { socket_id, channel_name }
//   - Réponse  : { auth: "key:signature" }
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static const String _host   = 'api.vigiroutes.com';
  static const String _appKey = '642e796713cd4093e508862ee725e601';
  static const int    _port   = 443;
  static const String _authUrl = 'https://$_host/api/user/broadcasting/auth';

  WebSocketChannel? _channel;
  String?           _socketId;
  bool              _connected = false;

  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final Dio _authDio = Dio();

  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  final Map<String, Set<String>> _subscriptions = {};
  final Set<String> _pendingSubscriptions = {};

  bool get isConnected => _connected;

  // ── Connexion ──────────────────────────────────────────────────────────

  Future<void> init(String sanctumToken) async {
    debugPrint('[WS] Init avec token ${sanctumToken.substring(0, 8)}...');
    await _connect();
  }

  Future<void> _connect() async {
    try {
      final uri = Uri.parse(
        'wss://$_host:$_port/app/$_appKey'
        '?protocol=7&client=dart&version=1.0&flash=false',
      );

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _connected = true;

      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);

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
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';
      final chan  = msg['channel'] as String? ?? '';

      if (event == 'pusher:ping') {
        _send({'event': 'pusher:pong', 'data': {}});
        return;
      }

      if (event == 'pusher:connection_established') {
        try {
          final data = msg['data'];
          final parsed = data is String
              ? jsonDecode(data) as Map<String, dynamic>
              : Map<String, dynamic>.from(data as Map);
          _socketId = parsed['socket_id'] as String?;
        } catch (e) {
          debugPrint('[WS] Impossible de lire le socket_id : $e');
        }
        debugPrint('[WS] Handshake OK (socket_id=$_socketId)');

        for (final channel in _subscriptions.keys) {
          _subscribeChannel(channel);
        }

        final pending = List<String>.from(_pendingSubscriptions);
        _pendingSubscriptions.clear();
        for (final channel in pending) {
          _subscribeChannel(channel);
        }
        return;
      }

      final key = '$chan:$event';
      if (_controllers.containsKey(key)) {
        final data = msg['data'];
        Map<String, dynamic> parsed;
        if (data is String) {
          parsed = jsonDecode(data) as Map<String, dynamic>;
        } else if (data is Map) {
          parsed = Map<String, dynamic>.from(data);
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

  // ── Souscription ───────────────────────────────────────────────────────

  Future<void> _subscribeChannel(String channel) async {
    if (!channel.startsWith('private-')) {
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel},
      });
      return;
    }

    if (_socketId == null) {
      debugPrint('[WS] Abonnement $channel mis en attente (socket_id absent)');
      _pendingSubscriptions.add(channel);
      return;
    }

    final token = await _getFreshToken();
    if (token == null) {
      debugPrint('[WS] Abonnement $channel différé (aucun token)');
      _pendingSubscriptions.add(channel);
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
          headers: {'Authorization': 'Bearer $token'},
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
        'data': {'channel': channel, 'auth': auth},
      });
      debugPrint('[WS] Abonné à $channel');
    } catch (e) {
      debugPrint('[WS] Échec auth canal $channel : $e');
    }
  }

  Future<String?> _getFreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('sanctum_token');
    } catch (e) {
      debugPrint('[WS] Impossible de lire le token : $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>> subscribeToIntervention(String userId) =>
      _subscribe('private-user.$userId', 'intervention.updated');

  Stream<Map<String, dynamic>> subscribeToAdminInterventions() =>
      _subscribe('private-admin.interventions', 'intervention.updated');

  Stream<Map<String, dynamic>> subscribeToEmergencies() =>
      _subscribe('private-admin.interventions', 'emergency.created');

  Stream<Map<String, dynamic>> _subscribe(String channel, String event) {
    final key = '$channel:$event';

    if (!_controllers.containsKey(key)) {
      _controllers[key] = StreamController<Map<String, dynamic>>.broadcast();
      _subscriptions.putIfAbsent(channel, () => {}).add(event);

      if (_connected && _socketId != null) {
        _subscribeChannel(channel);
      } else {
        _pendingSubscriptions.add(channel);
      }
    }

    return _controllers[key]!.stream;
  }

  // ── Déconnexion ────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    try {
      await _channel?.sink.close();
    } catch (_) {}

    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
    _subscriptions.clear();
    _pendingSubscriptions.clear();
    _socketId = null;
    _connected = false;
    debugPrint('[WS] Déconnecté');
  }
}