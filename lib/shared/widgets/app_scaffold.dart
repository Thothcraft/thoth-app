import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/application/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main scaffold with bottom navigation and app drawer.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/thoth_logo.png',
              height: 32,
              width: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.science, size: 32);
              },
            ),
            const SizedBox(width: 8),
            const Text(AppConstants.appName),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                auth.plan.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      body: child,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final int selectedIndex = _getSelectedIndex(location);

    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (index) => _onItemTapped(index, context),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.science),
          label: 'Research',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/images/thoth_logo.png',
                  height: 48,
                  width: 48,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.science,
                        size: 48, color: Colors.white);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_link),
            title: const Text('Pair a device'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.pair);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Shop Kits'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.shop);
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Plans & Pricing'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.plans);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Community'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.community);
            },
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contact & Join'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.contact);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('Privacy & Terms'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.legal);
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Open Portal'),
            onTap: () => _launchUrl(AppConstants.portalUrl),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(color: AppColors.textTertiaryLight),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith(AppRoutes.devices)) return 0;
    if (location.startsWith(AppRoutes.research)) return 1;
    if (location == AppRoutes.home) return 2;
    if (location.startsWith(AppRoutes.settings)) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.devices);
        break;
      case 1:
        context.go(AppRoutes.research);
        break;
      case 2:
        context.go(AppRoutes.home);
        break;
      case 3:
        context.go(AppRoutes.settings);
        break;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
