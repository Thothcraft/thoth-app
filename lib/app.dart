import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

class ThothcraftApp extends ConsumerWidget {
  const ThothcraftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Thothcraft',
      debugShowCheckedModeBanner: false,
      
      // Theme
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system, // TODO: Connect to settings provider
      
      // Routing
      routerConfig: appRouter,
      
      // Localization
      supportedLocales: const [
        Locale('en', 'US'),
      ],
    );
  }
}
