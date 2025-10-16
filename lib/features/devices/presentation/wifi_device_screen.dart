import 'package:flutter/material.dart';

/// WiFi Sensing Device Screen
class WifiDeviceScreen extends StatelessWidget {
  const WifiDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi Sensing')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Passive environmental sensing using WiFi signal analysis.',
              style: TextStyle(fontSize: 16),
            ),
            // TODO: Add detailed content
          ],
        ),
      ),
    );
  }
}
