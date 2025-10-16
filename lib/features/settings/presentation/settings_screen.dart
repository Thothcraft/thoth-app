import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings Screen - App preferences
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Theme'),
            subtitle: const Text('Light / Dark / System'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement theme selector
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement language selector
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.video_settings),
            title: const Text('Video Autoplay'),
            subtitle: const Text('Automatically play videos'),
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // TODO: Implement video autoplay toggle
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.network_check),
            title: const Text('Diagnostics'),
            subtitle: const Text('Network and system information'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement diagnostics screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement about dialog
            },
          ),
        ],
      ),
    );
  }
}
