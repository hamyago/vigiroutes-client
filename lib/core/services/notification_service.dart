import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Gère les notifications push FCM pour l'app Terrain (agents CT).
///
/// Types FCM attendus depuis le backend :
///   - booking_confirmed    → nouvelle réservation CT assignée à ce centre
///   - vehicle_at_center    → client arrivé avec son véhicule
///   - transport_update     → mise à jour transport/remorquage vers le centre
///   - vt_reminder_30d/15d/7d → rappels CT pour les clients du centre
///   - vt_expired           → CT expiré (action requise côté centre)
///
/// Usage : TerrainNotificationService.instance.init(navigatorKey)
class TerrainNotificationService {
  TerrainNotificationService._();
  static final instance = TerrainNotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Permissions FCM
    await FirebaseMessaging.instance.requestPermission(
      alert: true, sound: true, badge: true,
    );

    // Tap sur notification → app en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Cold start depuis une notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });

    // Foreground : Android n'affiche pas les FCM automatiquement
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ── Foreground ─────────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == null) return;

    final notification = message.notification;
    final title = notification?.title ?? _titleForType(type);
    final body  = notification?.body  ?? _bodyForType(type);

    _showLocalNotification(type: type, title: title, body: body);

    // Snackbar pour les types urgents
    switch (type) {
      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'transport_update':
        _showSnackbar(
          body,
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              final bookingId = message.data['booking_id'] as String?;
              if (bookingId != null) _navigate('/booking/$bookingId');
            },
          ),
        );
      case 'vt_reminder_7d':
      case 'vt_expired':
        _showSnackbar(body);
      default:
        break;
    }
  }

  // ── Tap (background / cold start) ──────────────────────────────────────────

  void _handleTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final bookingId = message.data['booking_id'] as String?;

    switch (type) {
      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'transport_update':
        if (bookingId != null) _navigate('/booking/$bookingId');
      default:
        _navigate('/home');
    }
  }

  // ── Notification locale ────────────────────────────────────────────────────

  Future<void> _showLocalNotification({
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      await _localNotifications.show(
        type.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'terrain_alerts',
            'Alertes Terrain CT',
            channelDescription: 'Notifications pour les agents du centre CT',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnackbar(String text, {SnackBarAction? action}) {
    final context = _navigatorKey?.currentContext;
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

  void _navigate(String route) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    Navigator.of(context).pushNamed(route);
  }

  String _titleForType(String type) => switch (type) {
        'booking_confirmed' => '✅ Nouvelle réservation CT',
        'vehicle_at_center' => '🏁 Véhicule arrivé au centre',
        'transport_update'  => '🚗 Mise à jour transport',
        'vt_reminder_30d'   => '📅 CT dans 30 jours',
        'vt_reminder_15d'   => '📅 CT dans 15 jours',
        'vt_reminder_7d'    => '⚠️ CT dans 7 jours',
        'vt_expired'        => '🚫 CT expiré',
        _                   => 'VigiRoutes Terrain',
      };

  String _bodyForType(String type) => switch (type) {
        'booking_confirmed' => 'Une nouvelle réservation a été confirmée.',
        'vehicle_at_center' => 'Le véhicule du client est arrivé. Procédez à l\'inspection.',
        'transport_update'  => 'Une mise à jour du transport est disponible.',
        'vt_reminder_7d'    => 'Rappel : contrôle technique dans 7 jours.',
        'vt_expired'        => 'Contrôle technique expiré — action requise.',
        _                   => 'Appuyez pour voir les détails.',
      };
}
