import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centralise la réaction aux notifications push reçues côté Client.
///
/// Types FCM gérés :
///   - intervention_update  → snackbar foreground + navigation vers /user/tracking/:id au tap
///   - no_provider          → snackbar "Aucun prestataire disponible" (foreground) + /user/tracking/:id au tap
///   - emergency            → snackbar foreground + navigation vers /user/emergency au tap
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

  /// À appeler une seule fois dans main(), après l'initialisation de Firebase.
  void init() {
    // Notification tapée alors que l'app était en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App lancée DEPUIS une notification (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });

    // Notification reçue pendant que l'app est au premier plan (Android ne
    // l'affiche pas automatiquement — on affiche un snackbar).
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ─── Foreground ────────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final notification = message.notification;

    switch (type) {
      case 'intervention_update':
      case 'no_provider':
        _showSnackbar(
          notification != null
              ? '${notification.title ?? ''} ${notification.body ?? ''}'.trim()
              : _labelForType(type!),
          action: type == 'no_provider' ? null : _interventionAction(message.data),
        );

      case 'emergency':
        _showSnackbar(
          notification != null
              ? '${notification.title ?? ''} ${notification.body ?? ''}'.trim()
              : '🚨 Urgence activée',
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
          notification != null
              ? '${notification.title ?? ''} ${notification.body ?? ''}'.trim()
              : _labelForType(type!),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => _navigateToCT(message.data),
          ),
        );

      // city_welcome ne se montre pas en foreground (pas de snackbar)
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

  String _labelForType(String type) => switch (type) {
        'no_provider'       => 'Aucun prestataire disponible pour le moment.',
        'vt_reminder_30d'   => '📅 Rappel : contrôle technique dans 30 jours.',
        'vt_reminder_15d'   => '📅 Rappel : contrôle technique dans 15 jours.',
        'vt_reminder_7d'    => '⚠️ Rappel : contrôle technique dans 7 jours.',
        'vt_expired'        => '🚫 Contrôle technique expiré.',
        'booking_confirmed' => '✅ Réservation CT confirmée.',
        'vehicle_at_center' => '🏁 Votre véhicule est au centre CT.',
        'vt_result'         => '📋 Résultat du contrôle technique disponible.',
        'transport_update'  => '🚗 Mise à jour du transport CT.',
        _                   => 'Nouvelle notification.',
      };
}
