import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// Centralise la réaction aux notifications push reçues côté Client.
///
/// Types FCM gérés :
///   - intervention_update  → notification locale foreground + navigation vers /user/tracking/:id au tap
///   - no_provider          → notification locale + snackbar "Aucun prestataire disponible"
///   - emergency            → notification locale + navigation vers /user/emergency au tap
///   - city_welcome         → /user/city-welcome (extra: payload)
///   - vt_reminder_30d/15d/7d/vt_expired → /ct/booking?vehicle_id=...
///   - booking_confirmed    → /ct/booking?booking_id=...&action=open_booking_qr
///   - vehicle_at_center    → /ct/booking?booking_id=...
///   - vt_result            → /ct/booking?booking_id=...&result=...
///   - transport_update     → /ct/booking?booking_id=...&provider_status=...
class NotificationRouterService {
  NotificationRouterService._();
  static final NotificationRouterService instance = NotificationRouterService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// À appeler une seule fois dans main(), après l'initialisation de Firebase
  /// et de flutter_local_notifications.
  void init() {
    // Notification tapée alors que l'app était en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App lancée DEPUIS une notification (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });

    // Notification reçue pendant que l'app est au premier plan.
    // Android ne l'affiche PAS automatiquement : on affiche une notification
    // locale + un snackbar pour les types les plus urgents.
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ─── Foreground ────────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == null) return;

    final notification = message.notification;
    final title = notification?.title ?? _titleForType(type);
    final body  = notification?.body  ?? _bodyForData(message.data);

    // Affiche une notification locale (visible même en foreground sur Android)
    _showLocalNotification(type: type, title: title, body: body, data: message.data);

    // Snackbar supplémentaire pour les types urgents nécessitant une action immédiate
    switch (type) {
      case 'intervention_update':
        _showSnackbar(
          body,
          action: _interventionAction(message.data),
        );

      case 'no_provider':
        _showSnackbar('Aucun prestataire disponible pour le moment.');

      case 'emergency':
        _showSnackbar(
          '🚨 Urgence activée',
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => _navigate('/user/emergency'),
          ),
        );

      // CT types : snackbar simple + action vers /ct/booking
      case 'vt_reminder_30d':
      case 'vt_reminder_15d':
      case 'vt_reminder_7d':
      case 'vt_expired':
      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'vt_result':
      case 'transport_update':
        _showSnackbar(
          body,
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => _navigateToCT(message.data),
          ),
        );

      // city_welcome : pas de snackbar en foreground
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

      case 'vt_reminder_30d':
      case 'vt_reminder_15d':
      case 'vt_reminder_7d':
      case 'vt_expired':
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
    try {
      await _localNotifications.show(
        type.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'intervention_updates',
            'Mises à jour interventions',
            channelDescription: 'Notifications de suivi de vos demandes d\'assistance',
            importance: type == 'emergency' ? Importance.max : Importance.high,
            priority : type == 'emergency' ? Priority.max  : Priority.high,
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
      // flutter_local_notifications non initialisé ou erreur → le snackbar suffit
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _navigateToCT(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final bookingId = data['booking_id'] as String?;
    final vehicleId = data['vehicle_id'] as String?;
    final result = data['result'] as String?;
    final providerStatus = data['provider_status'] as String?;
    final action = data['action'] as String?;

    final params = <String, String>{};
    if (bookingId != null) params['booking_id'] = bookingId;
    if (vehicleId != null) params['vehicle_id'] = vehicleId;
    if (result != null) params['result'] = result;
    if (providerStatus != null) params['provider_status'] = providerStatus;
    if (action != null) params['action'] = action;

    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final route = query.isNotEmpty ? '/ct/booking?$query' : '/ct/booking';
    _navigate(route);
  }

  SnackBarAction? _interventionAction(Map<String, dynamic> data) {
    final id = data['intervention_id'] as String?;
    if (id == null) return null;
    return SnackBarAction(
      label: 'Suivre',
      onPressed: () => _navigate('/user/tracking/$id'),
    );
  }

  void _showSnackbar(String text, {SnackBarAction? action}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
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

  String _titleForType(String type) => switch (type) {
        'intervention_update' => '🚗 Mise à jour intervention',
        'no_provider'         => '😔 Aucun prestataire disponible',
        'emergency'           => '🚨 Urgence activée',
        'booking_confirmed'   => '✅ Réservation CT confirmée',
        'vehicle_at_center'   => '🏁 Véhicule au centre CT',
        'vt_result'           => '📋 Résultat contrôle technique',
        'transport_update'    => '🚗 Mise à jour transport CT',
        'vt_reminder_30d'     => '📅 CT dans 30 jours',
        'vt_reminder_15d'     => '📅 CT dans 15 jours',
        'vt_reminder_7d'      => '⚠️ CT dans 7 jours',
        'vt_expired'          => '🚫 CT expiré',
        _                     => 'VigiRoutes',
      };

  String _bodyForData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    return switch (type) {
      'no_provider' => 'Aucun prestataire n\'est disponible pour le moment.',
      'vt_expired'  => 'Votre contrôle technique est expiré. Prenez rendez-vous.',
      _             => 'Appuyez pour voir les détails.',
    };
  }
}
