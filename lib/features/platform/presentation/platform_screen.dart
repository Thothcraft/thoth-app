import 'package:flutter/material.dart';
import '../../../shared/widgets/hero_section.dart';

/// Platform Screen - Federated Learning, Differential Privacy, Secure Aggregation
class PlatformScreen extends StatelessWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const HeroSection(
            title: 'Thothcraft Platform',
            subtitle:
                'Decentralized machine learning with privacy-preserving technologies. '
                'Build, train, and deploy ML models across distributed devices.',
          ),
          const SizedBox(height: 48),
          _buildFeatureSection(
            context,
            'Federated Learning',
            'Train models collaboratively across multiple devices without centralizing data',
            Icons.hub,
          ),
          _buildFeatureSection(
            context,
            'Differential Privacy',
            'Protect individual data points while enabling valuable insights',
            Icons.privacy_tip,
          ),
          _buildFeatureSection(
            context,
            'Secure Aggregation',
            'Combine model updates securely without exposing individual contributions',
            Icons.security,
          ),
          _buildFeatureSection(
            context,
            'Distributed Datasets',
            'Access and contribute to privacy-safe collaborative datasets',
            Icons.dataset,
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
