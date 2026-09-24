import 'dart:isolate';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_router_service.dart';
import 'core/services/service_type_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'shared/navigation/app_router.dart';

// ── Canal Android notifications interventions ──────────────────────────────

const AndroidNotificationChannel _interventionChannel = AndroidNotificationChannel(
  'intervention_updates',
  'Mises à jour interventions',
  description: 'Notifications de suivi de vos demandes d\'assistance',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Handler background / terminated ──────────────────────────────────────
//
// Tourne dans un isolate séparé. Affiche une notification locale
// pour les types importants (intervention_update, no_provider, etc.).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final data = message.data;
  final type = data['type'] as String?;

  // Types qui méritent une notification locale en background
  const handledTypes = {
    'intervention_update',
    'no_provider',
    'emergency',
    'booking_confirmed',
    'vehicle_at_center',
    'vt_result',
    'transport_update',
    'vt_reminder_30d',
    'vt_reminder_15d',
    'vt_reminder_7d',
    'vt_expired',
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
    'no_provider'   => 'Aucun prestataire n\'est disponible pour le moment.',
    'vt_expired'    => 'Votre contrôle technique est expiré. Prenez rendez-vous.',
    _               => 'Appuyez pour voir les détails.',
  };
}

// ── Entrée principale ─────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFF8B0000),
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
      );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics ──────────────────────────────────────────────────────────
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final list = pair as List<dynamic>;
    await FirebaseCrashlytics.instance.recordError(
      list.first, list.last as StackTrace?, fatal: true,
    );
  }).sendPort);

  // ── FCM background handler ───────────────────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── Permissions FCM ──────────────────────────────────────────────────────
  await FirebaseMessaging.instance.requestPermission(
    alert: true, sound: true, badge: true,
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
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_interventionChannel);

  // ── Services ─────────────────────────────────────────────────────────────
  ApiService.instance.init();
  await ServiceTypeService.instance.load();
  NotificationRouterService.instance.init();

  runApp(const VigiRoutesApp());
}

// ─────────────────────────────────────────────────────────────────────────────

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
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'VigiRoutes',
        debugShowCheckedModeBanner: false,
        // navigatorKey est passé au GoRouter dans app_router.dart :
        // GoRouter(navigatorKey: NotificationRouterService.instance.navigatorKey)
        // MaterialApp.router ne l'accepte pas directement.
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFFF6B35),
          useMaterial3: true,
          fontFamily: 'Poppins',
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        routerConfig: _router,
      );
}
