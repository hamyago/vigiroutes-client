// lib/core/services/notification_router_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Centralise la réaction aux notifications push reçues côté Client.
//
// ⚠️ COLD START : getInitialMessage() peut résoudre AVANT que le router soit
// monté. Dans ce cas, on stocke la route dans _pendingRoute et le router
// la consomme dès son initState (voir _RouterWidgetState dans main.dart).
//
// Types FCM gérés :
//   - intervention_update  → /user/tracking/:id
//   - no_provider          → snackbar
//   - emergency            → /user/emergency
//   - city_welcome         → /user/city-welcome
//   - booking_confirmed    → /ct/booking?...
//   - vehicle_at_center    → /ct/booking?...
//   - vt_result            → /ct/booking?...
//   - transport_update     → /ct/booking?...
//   - vt_reminder_*        → /ct/vehicles?vehicle_id=...
//   - vt_expired           → /ct/vehicles?vehicle_id=...
//   - ct_quote_received    → /ct/quote/:id
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

class NotificationRouterService {
  NotificationRouterService._();
  static final NotificationRouterService instance = NotificationRouterService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Route en attente si le router n'est pas encore monté (cold start).
  String? _pendingRoute;
  Object? _pendingExtra;

  /// Appelé par le router après montage pour récupérer la route en attente.
  (String?, Object?) consumePendingRoute() {
    final r = _pendingRoute;
    final e = _pendingExtra;
    _pendingRoute = null;
    _pendingExtra = null;
    return (r, e);
  }

  /// À appeler une seule fois dans main(), après l'initialisation de Firebase
  /// et de flutter_local_notifications.
  void init() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) { if (message != null) _handleTap(message); });

    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ─── Foreground ─────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    // ─── DEBUG LOGS ──────────────────────────────────────────────
    // Pour diagnostiquer : adb logcat | grep FCM-CT
    debugPrint('[FCM-CT] RAW '
        'type=${message.data['type']} '
        'title=${message.data['title']} '
        'body=${message.data['body']} '
        'status=${message.data['status']} '
        'booking_id=${message.data['booking_id']}');
    // ─────────────────────────────────────────────────────────────

    final type = message.data['type'] as String?;
    if (type == null) return;

    // FIX : le backend n'envoie plus 'notification' (data-only payload).
    // On lit title/body depuis data. Fallback sur _titleForType/_bodyForData
    // si le payload vient d'un canal legacy.
    final title = (message.data['title'] as String?) ?? _titleForType(type);
    final body  = (message.data['body']  as String?) ?? _bodyForData(message.data);

    _showLocalNotification(
      type: type, title: title, body: body, data: message.data,
    );

    switch (type) {
      case 'city_welcome':
        _showSnackbar(body,
            action: SnackBarAction(
                label: 'Voir',
                onPressed: () => _navigate('/user/city-welcome',
                    extra: message.data)));

      case 'intervention_update':
        _showSnackbar(body, action: _interventionAction(message.data));

      case 'no_provider':
        // no_provider snackbar désactivé : le RequestScreen affiche déjà
        // un dialog dédié (_showNoProviderDialog). Éviter le doublon.
        break;

      case 'emergency':
        _showSnackbar('🚨 Urgence activée',
            action: SnackBarAction(
                label: 'Voir',
                onPressed: () => _navigate('/user/emergency')));

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

      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'inspection_ongoing':
      case 'vt_result':
      case 'transport_update':
        _showSnackbar(body,
            action: SnackBarAction(
                label: 'Voir',
                onPressed: () => _navigateToCT(message.data)));

      case 'ct_quote_received':
        _showSnackbar(body,
            action: SnackBarAction(
                label: 'Voir le devis',
                onPressed: () {
                  final id = message.data['quote_request_id'] as String?;
                  if (id != null) _navigate('/ct/quote/$id');
                }));

      default:
        break;
    }
  }

  // ─── Tap (background / cold start) ──────────────────────────────────────

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
      case 'inspection_ongoing':
      case 'vt_result':
      case 'transport_update':
        _navigateToCT(message.data);

      case 'ct_quote_received':
        final qrId = message.data['quote_request_id'] as String?;
        if (qrId != null) _navigate('/ct/quote/$qrId');

      default:
        break;
    }
  }

  // ─── Notification locale foreground ─────────────────────────────────────

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
      // ID unique par notification : sans ça, Android écrase la précédente
      // (car type.hashCode est identique pour toutes les notifs du même type).
      // On combine le type, l'intervention_id et le status pour garantir
      // l'unicité → chaque mise à jour de statut apparaît séparément.
      final interventionId = data['intervention_id'] ?? '';
      final status = data['status'] ?? '';
      final uniqueId = '$type-$interventionId-$status'.hashCode;

      await _localNotifications.show(
        uniqueId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'intervention_updates',
            'Mises à jour interventions',
            channelDescription:
                "Notifications de suivi de vos demandes d'assistance",
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
    } catch (_) {}
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

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
    if (isCritical) {
      bg = Colors.red.shade700;
    } else if (isWarning) {
      bg = Colors.orange.shade700;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // 🔧 FIX : nettoie les SnackBars empilés avant d'afficher le nouveau.
    // Sans ça, les FCM en rafale créaient des "fantômes" qui traînaient
    // 6 secondes chacun pendant la navigation entre écrans.
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bg,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  /// Navigation déclenchée par une notification.
  ///
  /// ⚠️ FIX S13.6.1 : on utilise `go()` (et pas `push()`) pour REMPLACER
  /// la pile de navigation. Sans ça, chaque tap sur une notif empile un
  /// nouvel écran et l'utilisateur doit appuyer N fois sur "Retour" pour
  /// revenir à l'accueil.
  ///
  /// Si le router n'est pas encore monté (cold start), on stocke la route
  /// dans `_pendingRoute` — le router la consomme à son initState.
  void _navigate(String route, {Object? extra}) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[Nav] Router non monté, mise en attente : $route');
      _pendingRoute = route;
      _pendingExtra = extra;
      return;
    }
    try {
      context.go(route, extra: extra);
    } catch (e) {
      debugPrint('[Nav] Échec go immédiat, mise en attente : $e');
      _pendingRoute = route;
      _pendingExtra = extra;
    }
  }

  // ─── Labels par type ────────────────────────────────────────────────────

  String _titleForType(String type) => switch (type) {
        // ── Interventions (types spécifiques depuis le listener backend) ──
        'order_accepted'          => '✅ Prestataire en route',
        'order_started'           => '🔧 Intervention en cours',
        'order_completed'         => '🎉 Intervention terminée',
        'intervention_cancelled'  => '❌ Intervention annulée',
        'dispatching'             => '🔍 Recherche en cours',
        'no_provider_available'   => '😔 Aucun prestataire disponible',
        'order_declined'          => '🔄 Recherche en cours',

        // ── Legacy / générique ──
        'intervention_update' => '🚗 Mise à jour intervention',
        'no_provider'         => '😔 Aucun prestataire disponible',
        'emergency'           => '🚨 Urgence activée',
        'city_welcome'        => '👋 Bienvenue sur VigiRoutes',

        // ── CT (contrôle technique) ──
        'booking_confirmed'   => '✅ Réservation CT confirmée',
        'vehicle_at_center'   => '🏁 Véhicule au centre CT',
        'inspection_ongoing'  => '🔧 Contrôle en cours',
        'vt_result'           => '📋 Résultat contrôle technique',
        'transport_update'    => '🚗 Mise à jour transport CT',
        'vt_reminder_7d'      => '⚠️ CT dans 7 jours',
        'vt_reminder_3d'      => '🔔 CT dans 3 jours',
        'vt_reminder_1d'      => '🚨 CT demain !',
        'vt_expired'          => '🚫 CT expiré',
        'ct_quote_received'   => '💰 Devis CT disponible',

        // ── Crédit bas (app Pro) ──
        'credit_low'          => '⚠️ Crédit VigiRoutes presque épuisé',
        'credit_critical'     => '🔴 Crédit VigiRoutes épuisé',

        // ── Fallback ──
        _                     => 'VigiRoutes',
      };

  String _bodyForData(Map<String, dynamic> data) {
    final immat = data['registration_number'] as String? ?? 'Votre véhicule';
    final providerName = data['provider_name'] as String?;

    return switch (data['type'] as String? ?? '') {
      // ── Interventions ──
      'order_accepted'         => providerName != null
          ? '$providerName a accepté votre demande et arrive.'
          : 'Un prestataire a accepté votre demande et arrive.',
      'order_started'          => providerName != null
          ? 'Votre intervention est en cours avec $providerName.'
          : 'Votre intervention est en cours.',
      'order_completed'        => 'Votre intervention est terminée. Pensez à laisser un avis !',
      'intervention_cancelled' => 'Votre demande a été annulée.',
      'dispatching'            => 'Nous cherchons un prestataire disponible près de vous.',
      'no_provider_available'  => "Aucun prestataire n'est disponible pour le moment.",
      'order_declined'         => 'Un prestataire a refusé. Recherche en cours...',

      // ── Legacy ──
      'no_provider'     => "Aucun prestataire n'est disponible pour le moment.",

      // ── CT ──
      'inspection_ongoing' => 'Le contrôle technique de votre véhicule a démarré.',
      'vt_reminder_7d'  => '$immat — contrôle technique dans 7 jours. Prenez rendez-vous.',
      'vt_reminder_3d'  => '$immat — contrôle technique dans 3 jours ! Prenez rendez-vous.',
      'vt_reminder_1d'  => '$immat — contrôle technique DEMAIN ! Réservez maintenant.',
      'vt_expired'      => '$immat — contrôle technique expiré. Régularisez rapidement.',

      // ── Crédit bas ──
      'credit_low'      => 'Rechargez pour continuer à recevoir des demandes.',
      'credit_critical' => 'Votre crédit est épuisé. Rechargez pour recevoir de nouvelles demandes.',

      // ── Fallback ──
      _                 => 'Appuyez pour voir les détails.',
    };
  }
}