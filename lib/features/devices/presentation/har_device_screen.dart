import 'package:flutter/material.dart';

/// HAR Device Screen - Human Activity Recognition
class HarDeviceScreen extends StatelessWidget {
  const HarDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Human Activity Recognition')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track human activities using accelerometer, gyroscope, and magnetometer data.',
              style: TextStyle(fontSize: 16),
            ),
            // TODO: Add detailed content
          ],
        ),
      ),
    );
  }
}
