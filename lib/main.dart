import 'dart:isolate';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_router_service.dart';
import 'core/services/service_type_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'shared/navigation/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En release, une erreur de build affiche un écran gris muet. On la rend
  // lisible à l'écran pour pouvoir diagnostiquer sans câble/logcat.
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

  // Crashlytics
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

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        routerConfig: _router,
      );
}
