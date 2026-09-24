import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralise la réaction aux notifications push reçues côté Client.
///
/// Améliorations v2 :
///   - Déduplication par messageId (TTL 60 s) → pas de doublon si FCM livre
///     deux fois le même message.
///   - Conscience de la route courante : le snackbar est supprimé si
///     l'utilisateur est déjà sur l'écran cible.
///   - En foreground, la notification locale n'est affichée QUE pour
///     'emergency' (plein écran / heads-up critique). Pour les autres types,
///     le snackbar suffit — l'utilisateur est déjà dans l'app.
///   - Plugin flutter_local_notifications accepté depuis main.dart pour
///     partager l'instance déjà initialisée (évite les échecs silencieux).
///   - city_welcome : notifié une seule fois par ville. L'identifiant de ville
///     (city_id ou city_slug) est persisté dans SharedPreferences. La
///     notification ne revient que si le client entre dans une ville différente.
///
/// Types FCM gérés :
///   - intervention_update  → snackbar + navigation vers /user/tracking/:id au tap
///   - no_provider          → snackbar "Aucun prestataire disponible"
///   - emergency            → notification locale heads-up + snackbar + nav
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

  // Instance partagée depuis main.dart (déjà initialisée)
  FlutterLocalNotificationsPlugin? _localNotifications;

  // ── Déduplication ──────────────────────────────────────────────────────────
  // Stocke les messageId déjà traités avec leur timestamp.
  // Les entrées sont purgées après 60 secondes.
  final Map<String, DateTime> _seenIds = {};
  static const _dedupWindow = Duration(seconds: 60);

  /// À appeler une seule fois dans main(), après l'initialisation de Firebase
  /// et de flutter_local_notifications.
  ///
  /// [localNotifications] doit être l'instance déjà initialisée dans main().
  void init({FlutterLocalNotificationsPlugin? localNotifications}) {
    _localNotifications = localNotifications;

    // Notification tapée alors que l'app était en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App lancée DEPUIS une notification (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });

    // Notification reçue pendant que l'app est au premier plan.
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ─── Déduplication ─────────────────────────────────────────────────────────

  /// Retourne true si ce message a déjà été traité récemment.
  bool _isDuplicate(RemoteMessage message) {
    final id = message.messageId;
    if (id == null) return false; // pas d'id → on laisse passer

    _purgeOldIds();

    if (_seenIds.containsKey(id)) return true;
    _seenIds[id] = DateTime.now();
    return false;
  }

  void _purgeOldIds() {
    final cutoff = DateTime.now().subtract(_dedupWindow);
    _seenIds.removeWhere((_, time) => time.isBefore(cutoff));
  }

  // ─── Route awareness ───────────────────────────────────────────────────────

  /// Retourne le chemin de la route courante (ex. "/user/tracking/42").
  String? _currentRoute() {
    final context = navigatorKey.currentContext;
    if (context == null) return null;
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return null;
    }
  }

  /// Vérifie si l'utilisateur est déjà sur la route cible (ou un préfixe).
  bool _isAlreadyOn(String prefix) {
    final current = _currentRoute();
    return current != null && current.startsWith(prefix);
  }

  // ─── Foreground ────────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    if (_isDuplicate(message)) return;

    final type = message.data['type'] as String?;
    if (type == null) return;

    final notification = message.notification;
    final title = notification?.title ?? _titleForType(type);
    final body  = notification?.body  ?? _bodyForData(message.data);

    // Notification locale uniquement pour 'emergency' (heads-up / plein écran).
    // Pour les autres types, l'utilisateur est dans l'app : le snackbar suffit.
    if (type == 'emergency') {
      _showLocalNotification(type: type, title: title, body: body, data: message.data);
    }

    // city_welcome : vérification asynchrone (ville déjà vue ?)
    if (type == 'city_welcome') {
      _shouldShowCityWelcome(message.data).then((show) {
        if (!show) return;
        _showSnackbar(
          title,
          action: SnackBarAction(
            label: 'Découvrir',
            onPressed: () => _navigate('/user/city-welcome', extra: message.data),
          ),
        );
      });
      return;
    }

    switch (type) {
      case 'intervention_update':
        // Pas de snackbar si déjà sur le suivi de cette intervention
        final id = message.data['intervention_id'] as String?;
        if (id != null && _isAlreadyOn('/user/tracking/$id')) return;
        _showSnackbar(body, action: _interventionAction(message.data));

      case 'no_provider':
        _showSnackbar('Aucun prestataire disponible pour le moment.');

      // ── Notifications du flow commande ──────────────────────────────────
      case 'order_accepted':
        final acceptedId = message.data['intervention_id'] as String?;
        final providerName = message.data['provider_name'] as String? ?? 'Le prestataire';
        _showSnackbar(
          '✅ $providerName a accepté votre demande !',
          action: acceptedId != null
              ? SnackBarAction(
                  label: 'Suivre',
                  onPressed: () => _navigate('/user/tracking/$acceptedId'),
                )
              : null,
        );
        if (acceptedId != null && !_isAlreadyOn('/user/tracking/$acceptedId')) {
          Future.delayed(const Duration(milliseconds: 600), () {
            _navigate('/user/tracking/$acceptedId');
          });
        }

      case 'order_declined':
        // Le serveur relance vers le prestataire suivant automatiquement.
        // On informe juste le client qu'on cherche encore.
        _showSnackbar(
          '🔄 Recherche d\'un autre prestataire...',
        );
      // ─────────────────────────────────────────────────────────────────────

      case 'emergency':
        // Toujours affiché — urgence critique
        _showSnackbar(
          '🚨 Urgence activée',
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => _navigate('/user/emergency'),
          ),
        );

      case 'vt_reminder_30d':
      case 'vt_reminder_15d':
      case 'vt_reminder_7d':
      case 'vt_expired':
      case 'booking_confirmed':
      case 'vehicle_at_center':
      case 'vt_result':
      case 'transport_update':
        // Pas de snackbar si déjà dans le module CT
        if (_isAlreadyOn('/ct/booking')) return;
        _showSnackbar(
          body,
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => _navigateToCT(message.data),
          ),
        );

      default:
        break;
    }
  }

  // ─── city_welcome — une seule fois par ville ──────────────────────────────

  /// Clé SharedPreferences qui stocke le slug/id de la dernière ville notifiée.
  static const _kLastWelcomeCity = 'notif_last_welcome_city';

  /// Retourne true si ce city_welcome doit être affiché (ville nouvelle).
  /// Persiste l'identifiant de ville pour les appels suivants.
  Future<bool> _shouldShowCityWelcome(Map<String, dynamic> data) async {
    // Le backend doit envoyer city_id OU city_slug pour identifier la ville.
    final cityKey = (data['city_id'] ?? data['city_slug'])?.toString();
    if (cityKey == null || cityKey.isEmpty) return true; // pas d'id → affiche

    final prefs = await SharedPreferences.getInstance();
    final lastCity = prefs.getString(_kLastWelcomeCity);

    if (lastCity == cityKey) return false; // même ville → ignorer

    await prefs.setString(_kLastWelcomeCity, cityKey);
    return true;
  }

  // ─── Tap (background / cold start) ─────────────────────────────────────────

  void _handleTap(RemoteMessage message) {
    // Pas de déduplication sur les taps : le tap est intentionnel.
    final type = message.data['type'] as String?;

    switch (type) {
      case 'city_welcome':
        // Au tap, on navigue directement — l'utilisateur a déjà vu la notif.
        _navigate('/user/city-welcome', extra: message.data);

      case 'intervention_update':
      case 'no_provider':
        final id = message.data['intervention_id'] as String?;
        if (id != null) _navigate('/user/tracking/$id');

      case 'order_accepted':
        final acceptedId = message.data['intervention_id'] as String?;
        if (acceptedId != null) _navigate('/user/tracking/$acceptedId');

      case 'order_declined':
        // Tap sur "recherche en cours" → rien à faire, le serveur gère la cascade
        break;

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

  // ─── Notification locale (emergency uniquement en foreground) ───────────────

  Future<void> _showLocalNotification({
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final plugin = _localNotifications;
    if (plugin == null) return; // non initialisé → silencieux

    try {
      await plugin.show(
        type.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'intervention_updates',
            'Mises à jour interventions',
            channelDescription: 'Notifications de suivi de vos demandes d\'assistance',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
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
      // Erreur plugin → le snackbar suffit
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _navigateToCT(Map<String, dynamic> data) {
    final bookingId      = data['booking_id']      as String?;
    final vehicleId      = data['vehicle_id']       as String?;
    final result         = data['result']            as String?;
    final providerStatus = data['provider_status']   as String?;
    final action         = data['action']            as String?;

    final params = <String, String>{};
    if (bookingId      != null) params['booking_id']      = bookingId;
    if (vehicleId      != null) params['vehicle_id']       = vehicleId;
    if (result         != null) params['result']            = result;
    if (providerStatus != null) params['provider_status']   = providerStatus;
    if (action         != null) params['action']            = action;

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // évite l'empilement de snackbars
      ..showSnackBar(
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
        'order_accepted'      => '✅ Demande acceptée',
        'order_declined'      => '🔄 Recherche en cours',
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
