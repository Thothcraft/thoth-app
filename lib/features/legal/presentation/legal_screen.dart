import 'package:flutter/material.dart';

/// Legal Screen - Privacy Policy and Terms of Service
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Terms')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Privacy Policy',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your privacy is important to us. This policy outlines how we collect, '
            'use, and protect your data when using Thothcraft devices and services.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          const Text(
            'Terms of Service',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'By using Thothcraft products and services, you agree to these terms. '
            'Please read them carefully.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // TODO: Open full privacy policy
            },
            child: const Text('Read Full Privacy Policy'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Open full terms
            },
            child: const Text('Read Full Terms of Service'),
          ),
        ],
      ),
    );
  }
}
