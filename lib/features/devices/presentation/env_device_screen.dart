import 'package:flutter/material.dart';

/// Environmental Monitoring Device Screen
class EnvDeviceScreen extends StatelessWidget {
  const EnvDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Environmental Monitoring')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monitor temperature, humidity, pressure, and air quality.',
              style: TextStyle(fontSize: 16),
            ),
            // TODO: Add detailed content
          ],
        ),
      ),
    );
  }
}
