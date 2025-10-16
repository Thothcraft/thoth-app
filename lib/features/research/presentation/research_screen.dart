import 'package:flutter/material.dart';

/// Research Screen - Publications and Press
class ResearchScreen extends StatelessWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Research & Publications')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Explore our research papers, talks, and contributions to the field of federated learning and IoT.',
              style: TextStyle(fontSize: 16),
            ),
            // TODO: Add publication list
          ],
        ),
      ),
    );
  }
}
