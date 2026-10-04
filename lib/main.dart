// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// Point d'entrée de VigiRoutes Client.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:isolate';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/services/api_service.dart';
import 'core/services/notification_router_service.dart';
import 'core/services/service_type_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'shared/navigation/app_router.dart';

const AndroidNotificationChannel _interventionChannel = AndroidNotificationChannel(
  'intervention_updates',
  'Mises à jour interventions',
  description: "Notifications de suivi de vos demandes d'assistance",
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Handler background / terminated ──────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  final data = message.data;
  final type = data['type'] as String?;

  const handledTypes = {
    // ── Interventions (dépannage, remorquage) ──
    'order_accepted',
    'order_started',
    'order_completed',
    'intervention_cancelled',
    'dispatching',
    'no_provider_available',
    'order_declined',
    'intervention_update',
    'no_provider',
    // ── Urgence ──
    'emergency',
    // ── CT ──
    'booking_confirmed',
    'vehicle_at_center',
    'inspection_ongoing',
    'vt_result',
    'transport_update',
    'vt_reminder_30d',
    'vt_reminder_15d',
    'vt_reminder_7d',
    'vt_reminder_3d',
    'vt_reminder_1d',
    'vt_expired',
    // ── Devis CT ──
    'ct_quote_received',
    // ── Crédit (app Pro) ──
    'credit_low',
    'credit_critical',
    // ── City welcome ──
    'city_welcome',
  };
  if (type == null || !handledTypes.contains(type)) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  final notification = message.notification;
  final title = notification?.title ?? _titleForType(type);
  final body  = notification?.body  ?? _bodyForData(data);

  await plugin.show(
    type.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'intervention_updates',
        'Mises à jour interventions',
        channelDescription: "Notifications de suivi de vos demandes d'assistance",
        importance: type == 'emergency' ? Importance.max : Importance.high,
        priority: type == 'emergency' ? Priority.max : Priority.high,
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
}

String _titleForType(String type) => switch (type) {
      // ── Interventions ──
      'order_accepted'         => '✅ Prestataire en route',
      'order_started'          => '🔧 Intervention en cours',
      'order_completed'        => '🎉 Intervention terminée',
      'intervention_cancelled' => '❌ Intervention annulée',
      'dispatching'            => '🔍 Recherche en cours',
      'no_provider_available'  => '😔 Aucun prestataire disponible',
      'order_declined'         => '🔄 Recherche en cours',
      'intervention_update'    => '🚗 Mise à jour intervention',
      'no_provider'            => '😔 Aucun prestataire disponible',
      // ── Urgence ──
      'emergency'              => '🚨 Urgence activée',
      // ── CT ──
      'booking_confirmed'      => '✅ Réservation CT confirmée',
      'vehicle_at_center'      => '🏁 Véhicule au centre CT',
      'inspection_ongoing'     => '🔧 Contrôle en cours',
      'vt_result'              => '📋 Résultat contrôle technique',
      'transport_update'       => '🚗 Mise à jour transport CT',
      'vt_reminder_30d'        => '📅 CT dans 30 jours',
      'vt_reminder_15d'        => '📅 CT dans 15 jours',
      'vt_reminder_7d'         => '⚠️ CT dans 7 jours',
      'vt_reminder_3d'         => '🔔 CT dans 3 jours',
      'vt_reminder_1d'         => '🚨 CT demain !',
      'vt_expired'             => '🚫 CT expiré',
      // ── Devis CT ──
      'ct_quote_received'      => '💰 Devis CT disponible',
      // ── Crédit ──
      'credit_low'             => '⚠️ Crédit presque épuisé',
      'credit_critical'        => '🔴 Crédit épuisé',
      // ── City welcome ──
      'city_welcome'           => '👋 Bienvenue sur VigiRoutes',
      // ── Fallback ──
      _                        => 'VigiRoutes',
    };

String _bodyForData(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';
  final immat = data['registration_number'] as String? ?? 'Votre véhicule';
  final providerName = data['provider_name'] as String?;
  final amount = data['amount'] as String?;

  return switch (type) {
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
    'intervention_update'    => 'Une mise à jour de votre intervention est disponible.',
    'no_provider'            => "Aucun prestataire n'est disponible pour le moment.",

    // ── Urgence ──
    'emergency'              => 'Votre demande d'urgence a été enregistrée.',

    // ── CT ──
    'booking_confirmed'      => 'Votre réservation CT est confirmée. Votre QR code est disponible.',
    'vehicle_at_center'      => 'Votre véhicule est arrivé au centre. Le contrôle va commencer.',
    'inspection_ongoing'     => 'Le contrôle technique de votre véhicule a démarré.',
    'vt_result'              => 'Le résultat de votre contrôle technique est disponible.',
    'transport_update'       => 'Une mise à jour du transport de votre véhicule est disponible.',
    'vt_reminder_30d'        => '$immat — contrôle technique dans 30 jours.',
    'vt_reminder_15d'        => '$immat — contrôle technique dans 15 jours.',
    'vt_reminder_7d'         => '$immat — contrôle technique dans 7 jours. Prenez rendez-vous.',
    'vt_reminder_3d'         => '$immat — contrôle technique dans 3 jours ! Prenez rendez-vous.',
    'vt_reminder_1d'         => '$immat — contrôle technique DEMAIN ! Réservez maintenant.',
    'vt_expired'             => '$immat — contrôle technique expiré. Régularisez rapidement.',

    // ── Devis CT ──
    'ct_quote_received'      => amount != null
        ? 'Votre devis de $amount FCFA est prêt. Consultez-le et acceptez ou refusez dans l'app.'
        : 'Votre devis CT est disponible. Consultez-le dans l'app.',

    // ── Crédit ──
    'credit_low'             => 'Rechargez pour continuer à recevoir des demandes.',
    'credit_critical'        => 'Votre crédit est épuisé. Rechargez pour recevoir de nouvelles demandes.',

    // ── City welcome ──
    'city_welcome'           => 'Bienvenue sur VigiRoutes !',

    // ── Fallback ──
    _                        => 'Appuyez pour voir les détails.',
  };
}

// ── Entrée principale ─────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr', null);

  // FIX : Directionality requis pour utiliser Material hors MaterialApp
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFF8B0000),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              child: Text(
                'ERREUR UI:\n\n${details.exceptionAsString()}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics ──────────────────────────────────────────────────────────
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // FIX : variable sans underscore (no_leading_underscores_for_local_identifiers)
  final errorPort = RawReceivePort((pair) async {
    final list = pair as List<dynamic>;
    await FirebaseCrashlytics.instance.recordError(
      list.first,
      list.last as StackTrace?,
      fatal: true,
    );
  });
  Isolate.current.addErrorListener(errorPort.sendPort);

  // ── FCM background handler ───────────────────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── Permissions FCM ──────────────────────────────────────────────────────
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    sound: true,
    badge: true,
  );

  // ── flutter_local_notifications — canal Android ──────────────────────────
  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    ),
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_interventionChannel);

  // ── Services ─────────────────────────────────────────────────────────────
  ApiService.instance.init();
  await ServiceTypeService.instance.load();

  NotificationRouterService.instance.init();

  runApp(const VigiRoutesApp());
}

class VigiRoutesApp extends StatelessWidget {
  const VigiRoutesApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: const _RouterWidget(),
      );
}

class _RouterWidget extends StatefulWidget {
  const _RouterWidget();

  @override
  State<_RouterWidget> createState() => _RouterWidgetState();
}

class _RouterWidgetState extends State<_RouterWidget> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(context.read<AuthController>());

    // FIX COLD START : consomme la route en attente dès que le router est prêt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final (route, extra) =
          NotificationRouterService.instance.consumePendingRoute();
      if (route != null) {
        debugPrint('[Nav] Navigation post-mount vers : $route');
        _router.push(route, extra: extra);
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'VigiRoutes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFFF6B35),
          useMaterial3: true,
          fontFamily: 'Poppins',
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        routerConfig: _router,
      );
}