import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centralise la réaction aux notifications push reçues côté Client.
///
/// Actuellement géré :
///   - type = "city_welcome" → ouvre l'écran de bienvenue avec le top 5
///     des prestataires par secteur de la ville détectée, via la route
///     GoRouter '/user/city-welcome' (voir app_router.dart). Les données
///     du payload sont transmises via `extra` pour éviter de les faire
///     transiter par l'URL (trop volumineuses pour des query params).
///
/// Utilise un GlobalKey<NavigatorState> pour accéder au BuildContext
/// courant indépendamment du widget actif au moment où la notification
/// est tapée (cold start, background, ou foreground).
class NotificationRouterService {
  NotificationRouterService._();
  static final NotificationRouterService instance = NotificationRouterService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// À appeler une seule fois dans main(), après l'initialisation de Firebase.
  void init() {
    // Notification tapée alors que l'app était en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotification);

    // Vérifie si l'app a été lancée DEPUIS une notification (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotification(message);
    });
  }

  void _handleNotification(RemoteMessage message) {
    final type = message.data['type'];
    if (type != 'city_welcome') return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    context.push('/user/city-welcome', extra: message.data);
  }
}
