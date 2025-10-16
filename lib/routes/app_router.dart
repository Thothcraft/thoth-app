import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/features/presentation/features_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/devices/presentation/har_device_screen.dart';
import '../features/devices/presentation/wifi_device_screen.dart';
import '../features/devices/presentation/env_device_screen.dart';
import '../features/demos/presentation/demos_screen.dart';
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
  static const String features = '/features';
  static const String devices = '/devices';
  static const String devicesHar = '/devices/har';
  static const String devicesWifi = '/devices/wifi';
  static const String devicesEnv = '/devices/env';
  static const String demos = '/demos';
  static const String shop = '/shop';
  static const String plans = '/plans';
  static const String community = '/community';
  static const String research = '/research';
  static const String contact = '/contact';
  static const String settings = '/settings';
  static const String legal = '/legal';
}

/// Go Router Configuration
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    // Shell Route - wraps main navigation routes with bottom nav
    ShellRoute(
      builder: (context, state, child) {
        return AppScaffold(child: child);
      },
      routes: [
        // Home (Bottom Nav Tab 1)
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        
        // Features (Bottom Nav Tab 2)
        GoRoute(
          path: AppRoutes.features,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FeaturesScreen(),
          ),
        ),
        
        // Devices (Bottom Nav Tab 3) with sub-routes
        GoRoute(
          path: AppRoutes.devices,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DevicesScreen(),
          ),
          routes: [
            GoRoute(
              path: 'har',
              builder: (context, state) => const HarDeviceScreen(),
            ),
            GoRoute(
              path: 'wifi',
              builder: (context, state) => const WifiDeviceScreen(),
            ),
            GoRoute(
              path: 'env',
              builder: (context, state) => const EnvDeviceScreen(),
            ),
          ],
        ),
        
        // Demos (Bottom Nav Tab 4)
        GoRoute(
          path: AppRoutes.demos,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DemosScreen(),
          ),
        ),
      ],
    ),
    
    // Drawer Routes (not in bottom nav)
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
      path: AppRoutes.research,
      builder: (context, state) => const ResearchScreen(),
    ),
    GoRoute(
      path: AppRoutes.contact,
      builder: (context, state) => const ContactScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.legal,
      builder: (context, state) => const LegalScreen(),
    ),
  ],
  
  // Error handling
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.uri.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
