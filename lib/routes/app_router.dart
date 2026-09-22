import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/features/presentation/features_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/devices/presentation/har_device_screen.dart';
import '../features/devices/presentation/wifi_device_screen.dart';
import '../features/devices/presentation/env_device_screen.dart';
import '../features/demos/presentation/demos_screen.dart';
import '../features/live/presentation/live_screen.dart';
import '../features/pairing/presentation/pairing_screen.dart';
import '../features/research/presentation/research_screen.dart';
import '../features/contact/presentation/contact_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/legal/presentation/legal_screen.dart';
import '../features/shop/presentation/shop_screen.dart';
import '../features/plans/presentation/plans_screen.dart';
import '../features/community/presentation/community_screen.dart';
import '../shared/widgets/app_scaffold.dart';

/// Route paths
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String features = '/features';
  static const String devices = '/devices';
  static const String pair = '/pair';
  static const String demos = '/demos';
  static const String shop = '/shop';
  static const String plans = '/plans';
  static const String community = '/community';
  static const String research = '/research';
  static const String contact = '/contact';
  static const String settings = '/settings';
  static const String legal = '/legal';
}

/// Router is a provider so redirects react to auth state changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.devices,
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final onLogin = state.uri.path == AppRoutes.login;
      if (!auth.isAuthenticated && !onLogin) return AppRoutes.login;
      if (auth.isAuthenticated && onLogin) return AppRoutes.devices;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Shell — bottom navigation tabs
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.devices,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DevicesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.research,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ResearchScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
        ],
      ),

      // Full-screen routes
      GoRoute(
        path: AppRoutes.pair,
        builder: (context, state) => const PairingScreen(),
      ),
      GoRoute(
        path: '/devices/:id/live',
        builder: (context, state) =>
            LiveScreen(deviceId: state.pathParameters['id']!),
      ),

      // Marketing / info pages (drawer)
      GoRoute(
        path: AppRoutes.features,
        builder: (context, state) => const FeaturesScreen(),
      ),
      GoRoute(
        path: AppRoutes.demos,
        builder: (context, state) => const DemosScreen(),
      ),
      GoRoute(
        path: AppRoutes.shop,
        builder: (context, state) => const ShopScreen(),
      ),
      GoRoute(
        path: AppRoutes.plans,
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: AppRoutes.community,
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: AppRoutes.contact,
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: AppRoutes.legal,
        builder: (context, state) => const LegalScreen(),
      ),
      GoRoute(
        path: '/devices/har',
        builder: (context, state) => const HarDeviceScreen(),
      ),
      GoRoute(
        path: '/devices/wifi',
        builder: (context, state) => const WifiDeviceScreen(),
      ),
      GoRoute(
        path: '/devices/env',
        builder: (context, state) => const EnvDeviceScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found',
                style: Theme.of(context).textTheme.headlineMedium,),
            const SizedBox(height: 8),
            Text(state.uri.toString(),
                style: Theme.of(context).textTheme.bodyMedium,),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.devices),
              child: const Text('Go to Devices'),
            ),
          ],
        ),
      ),
    ),
  );
});
