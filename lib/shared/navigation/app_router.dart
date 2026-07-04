import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/phone_auth_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/action_choice_screen.dart';
import '../../features/home/controllers/home_controller.dart';
import '../../features/history/screens/history_screen.dart' as hist;
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/vehicles_screen.dart';
import '../../features/profile/screens/user_reviews_screen.dart';
import '../../features/reviews/screens/review_screen.dart';
import '../../features/request/screens/request_screen.dart';
import '../../features/request/controllers/request_controller.dart';
import '../../features/tracking/screens/tracking_screen.dart' as track;
import '../../features/emergency/screens/emergency_screen.dart';
import '../../features/emergency/controllers/emergency_controller.dart';
import '../../core/models/models.dart';
import '../../core/services/notification_router_service.dart';
import '../../features/home/screens/city_welcome_screen.dart';

class UserShell extends StatefulWidget {
  final Widget child;
  const UserShell({super.key, required this.child});
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _idx = 0;
  static const _routes = ['/user/home', '/user/profile'];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: widget.child,
        floatingActionButton: SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            heroTag: 'action_fab',
            onPressed: () => context.push('/user/action'),
            backgroundColor: const Color(0xFFFF6B35),
            elevation: 6,
            shape: const CircleBorder(),
            child: const Icon(Icons.support_agent,
                color: Colors.white, size: 38),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: Colors.white,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              Expanded(
                  child: _NavItem(
                      icon: Icons.map_outlined,
                      activeIcon: Icons.map,
                      label: 'Carte',
                      isActive: _idx == 0,
                      onTap: () {
                        setState(() => _idx = 0);
                        context.go(_routes[0]);
                      })),
              const SizedBox(width: 88),
              Expanded(
                  child: _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profil',
                      isActive: _idx == 1,
                      onTap: () {
                        setState(() => _idx = 1);
                        context.go(_routes[1]);
                      })),
            ]),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFFFF6B35) : Colors.grey),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFFFF6B35) : Colors.grey)),
        ]),
      );
}

GoRouter buildRouter(AuthController auth) => GoRouter(
      navigatorKey: NotificationRouterService.instance.navigatorKey,
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (ctx, state) {
        final loc       = state.matchedLocation;
        final authState = auth.state;
        final isLoading = authState == AuthState.unknown;
        final isAuth    = authState == AuthState.authenticated;
        final onSplash  = loc == '/';

        if (onSplash) return null;
        if (loc.startsWith('/auth')) return null;
        if (isLoading) return null;
        if (!isAuth && loc != '/onboarding') return '/onboarding';
        if (isAuth && loc == '/onboarding') {
          if (auth.isProvider) return '/provider/home';
          if (auth.isUser)     return '/user/home';
          return null;
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(
            path: '/auth/phone',
            builder: (ctx, s) => PhoneAuthScreen(
                isProvider: s.uri.queryParameters['role'] == 'provider')),
        GoRoute(
            path: '/auth/otp',
            builder: (ctx, s) {
              final e = s.extra as Map<String, dynamic>? ?? {};
              return OtpScreen(
                  phone: e['phone'] as String? ?? '',
                  isProvider: e['isProvider'] as bool? ?? false);
            }),
        GoRoute(
            path: '/auth/profile-setup',
            builder: (ctx, s) {
              final e = s.extra as Map<String, dynamic>? ?? {};
              return ProfileSetupScreen(
                  isProvider: e['isProvider'] as bool? ?? false);
            }),

        ShellRoute(
          builder: (_, __, child) => UserShell(child: child),
          routes: [
            GoRoute(
                path: '/user/home',
                builder: (_, __) => ChangeNotifierProvider(
                      create: (_) => HomeController(),
                      child: const UserHomeScreen(),
                    )),
            GoRoute(
                path: '/user/history',
                builder: (_, __) => const hist.HistoryScreen()),
            GoRoute(
                path: '/user/profile',
                builder: (_, __) => const UserProfileScreen()),
          ],
        ),

        GoRoute(
            path: '/user/action',
            builder: (_, __) => const ActionChoiceScreen()),
        GoRoute(
            path: '/user/request',
            builder: (ctx, s) => ChangeNotifierProvider(
                  create: (_) => RequestController(),
                  child: RequestScreen(
                      preselectedProvider: s.extra as ProviderModel?),
                )),
        GoRoute(
            path: '/user/tracking/:id',
            builder: (ctx, s) => track.TrackingScreen(
                interventionId: s.pathParameters['id']!)),
        GoRoute(
            path: '/user/edit-profile',
            builder: (_, __) => const EditProfileScreen()),
        GoRoute(
            path: '/user/vehicles',
            builder: (_, __) => const VehiclesScreen()),
        GoRoute(
            path: '/user/reviews',
            builder: (_, __) => const UserReviewsScreen()),
        GoRoute(
            path: '/user/review/:id',
            builder: (ctx, s) => ReviewScreen(
                interventionId: s.pathParameters['id']!)),
        GoRoute(
            path: '/user/emergency',
            builder: (_, __) => const _EmergencyRoute()),
        GoRoute(
            path: '/user/city-welcome',
            builder: (ctx, s) => CityWelcomeScreen.fromNotificationData(
                Map<String, dynamic>.from(s.extra as Map))),
      ],
    );

class _EmergencyRoute extends StatelessWidget {
  const _EmergencyRoute();
  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<EmergencyController>(
        create: (_) => EmergencyController(),
        child: const EmergencyScreen(),
      );
}