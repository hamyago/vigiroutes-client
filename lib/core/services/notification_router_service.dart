// services/notification_router_service.dart
// Centralise la réaction aux notifications push reçues côté Client.
//
// Types FCM gérés :
//   - intervention_update  → /user/tracking/:id
//   - no_provider          → snackbar
//   - emergency            → /user/emergency
//   - city_welcome         → /user/city-welcome
//   - booking_confirmed    → /ct/booking?booking_id=...&action=open_booking_qr
//   - vehicle_at_center    → /ct/booking?booking_id=...
//   - vt_result            → /ct/booking?booking_id=...&result=...
//   - transport_update     → /ct/booking?booking_id=...&provider_status=...
//   - vt_reminder_7d       → /ct/vehicles?vehicle_id=...  (+ snackbar warning)
//   - vt_reminder_3d       → /ct/vehicles?vehicle_id=...  (+ snackbar critical)
//   - vt_reminder_1d       → /ct/vehicles?vehicle_id=...  (+ snackbar critical)
//   - vt_expired           → /ct/vehicles?vehicle_id=...

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

class NotificationRouterService {
  NotificationRouterService._();
  static final NotificationRouterService instance = NotificationRouterService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// À appeler une seule fois dans main(), après l'initialisation de Firebase
  /// et de flutter_local_notifications.
  void init() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) { if (message != null) _handleTap(message); });
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ─── Foreground ─────────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == null) return;

    final notification = message.notification;
    final title = notification?.title ?? _titleForType(type);
    final body  = notification?.body  ?? _bodyForData(message.data);

    _showLocalNotification(type: type, title: title, body: body, data: message.data);

    switch (type) {
      case 'intervention_update':
        _showSnackbar(body, action: _interventionAction(message.data));

      case 'no_provider':
        _showSnackbar('Aucun prestataire disponible pour le moment.');

      case 'emergency':
        _showSnackbar('🚨 Urgence activée',
            action: SnackBarAction(
                label: 'Voir',
                onPressed: () => _navigate('/user/emergency')));

      // ── CT reminders ──────────────────────────────────────────────────────
      case 'vt_reminder_7d':
        _showSnackbar(body,
            isWarning: true,
            action: SnackBarAction(
                label: 'Voir',
                onPressed: () => _navigateToVehicle(message.data)));

      case 'vt_reminder_3d':
      case 'vt_reminder_1d':
        _showSnackbar(body,
            isCritical: true,
            action: SnackBarAction(
                label: 'Prendre RDV',
                onPressed: () => _navigateToCT(message.data)));

      case 'vt_expired':
        _showSnackbar(body,
            isCritical: true,
            action: SnackBarAction(
                label: 'Réserver',
                onPressed: () => _navigateToCT(message.data)));

      // ── Autres CT ─────────────────────────────────────────────────────────
      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'vt_result':
      case 'transport_update':
        _showSnackbar(body,
            action: SnackBarAction(
                label: 'Voir',
                onPressed: () => _navigateToCT(message.data)));

      default:
        break;
    }
  }

  // ─── Tap (background / cold start) ─────────────────────────────────────────

  void _handleTap(RemoteMessage message) {
    final type = message.data['type'] as String?;

    switch (type) {
      case 'city_welcome':
        _navigate('/user/city-welcome', extra: message.data);

      case 'intervention_update':
      case 'no_provider':
        final id = message.data['intervention_id'] as String?;
        if (id != null) _navigate('/user/tracking/$id');

      case 'emergency':
        _navigate('/user/emergency');

      // Rappels CT → ouvrir la fiche véhicule + proposer RDV
      case 'vt_reminder_7d':
      case 'vt_reminder_3d':
      case 'vt_reminder_1d':
      case 'vt_expired':
        final vehicleId = message.data['vehicle_id'] as String?;
        if (vehicleId != null) {
          _navigate('/ct/vehicles', extra: {'vehicle_id': vehicleId});
        } else {
          _navigateToCT(message.data);
        }

      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'vt_result':
      case 'transport_update':
        _navigateToCT(message.data);

      default:
        break;
    }
  }

  // ─── Notification locale foreground ─────────────────────────────────────────

  Future<void> _showLocalNotification({
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final isCritical = type == 'emergency' ||
        type == 'vt_reminder_1d' ||
        type == 'vt_expired';

    try {
      await _localNotifications.show(
        type.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'intervention_updates',
            'Mises à jour interventions',
            channelDescription:
                'Notifications de suivi de vos demandes d\'assistance',
            importance: isCritical ? Importance.max : Importance.high,
            priority:   isCritical ? Priority.max  : Priority.high,
            fullScreenIntent: type == 'emergency',
            playSound: true,
            enableVibration: true,
            ticker: title,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {
      // flutter_local_notifications non initialisé → le snackbar suffit
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _navigateToCT(Map<String, dynamic> data) {
    final params = <String, String>{};
    void add(String k) {
      final v = data[k] as String?;
      if (v != null) params[k] = v;
    }
    add('booking_id');
    add('vehicle_id');
    add('result');
    add('provider_status');
    add('action');

    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    _navigate(query.isNotEmpty ? '/ct/booking?$query' : '/ct/booking');
  }

  void _navigateToVehicle(Map<String, dynamic> data) {
    final vehicleId = data['vehicle_id'] as String?;
    if (vehicleId != null) {
      _navigate('/ct/vehicles?vehicle_id=$vehicleId');
    } else {
      _navigate('/ct/booking');
    }
  }

  SnackBarAction? _interventionAction(Map<String, dynamic> data) {
    final id = data['intervention_id'] as String?;
    if (id == null) return null;
    return SnackBarAction(
        label: 'Suivre', onPressed: () => _navigate('/user/tracking/$id'));
  }

  void _showSnackbar(
    String text, {
    SnackBarAction? action,
    bool isWarning  = false,
    bool isCritical = false,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Color bg = Colors.grey.shade900;
    if (isCritical) bg = Colors.red.shade700;
    else if (isWarning) bg = Colors.orange.shade700;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bg,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  void _navigate(String route, {Object? extra}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    context.push(route, extra: extra);
  }

  // ─── Labels par type ────────────────────────────────────────────────────────

  String _titleForType(String type) => switch (type) {
        'intervention_update' => '🚗 Mise à jour intervention',
        'no_provider'         => '😔 Aucun prestataire disponible',
        'emergency'           => '🚨 Urgence activée',
        'booking_confirmed'   => '✅ Réservation CT confirmée',
        'vehicle_at_center'   => '🏁 Véhicule au centre CT',
        'vt_result'           => '📋 Résultat contrôle technique',
        'transport_update'    => '🚗 Mise à jour transport CT',
        'vt_reminder_7d'      => '⚠️ CT dans 7 jours',
        'vt_reminder_3d'      => '🔔 CT dans 3 jours',
        'vt_reminder_1d'      => '🚨 CT demain !',
        'vt_expired'          => '🚫 CT expiré',
        _                     => 'VigiRoutes',
      };

  String _bodyForData(Map<String, dynamic> data) {
    final immat = data['registration_number'] as String? ?? 'Votre véhicule';
    return switch (data['type'] as String? ?? '') {
      'vt_reminder_7d'  => '$immat — contrôle technique dans 7 jours. Prenez rendez-vous.',
      'vt_reminder_3d'  => '$immat — contrôle technique dans 3 jours ! Prenez rendez-vous.',
      'vt_reminder_1d'  => '$immat — contrôle technique DEMAIN ! Réservez maintenant.',
      'vt_expired'      => '$immat — contrôle technique expiré. Régularisez rapidement.',
      'no_provider'     => 'Aucun prestataire n\'est disponible pour le moment.',
      _                 => 'Appuyez pour voir les détails.',
    };
  }
}
