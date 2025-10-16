import 'package:flutter/material.dart';

/// Demos Screen - Video gallery and demonstrations
class DemosScreen extends StatelessWidget {
  const DemosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demos & Tutorials',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'See Thoth in action with our demo videos and tutorials',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          _buildDemoCard(context, 'Getting Started', 'Setup your device in 60 seconds'),
          const SizedBox(height: 16),
          _buildDemoCard(context, 'First Project', 'Build your first AI/IoT project'),
          const SizedBox(height: 16),
          _buildDemoCard(context, 'Sensor Setup', 'Configure multiple sensors'),
        ],
      ),
    );
  }

  Widget _buildDemoCard(BuildContext context, String title, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline, size: 64),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
