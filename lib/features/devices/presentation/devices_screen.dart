import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../routes/app_router.dart';

/// Devices Screen - Main hub for Thoth hardware kits
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thoth Devices',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Explore our range of IoT devices and sensors',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          _buildDeviceCard(
            context,
            'Human Activity Recognition',
            'Motion sensing and activity tracking with IMU sensors',
            Icons.directions_walk,
            () => context.push(AppRoutes.devicesHar),
          ),
          const SizedBox(height: 16),
          _buildDeviceCard(
            context,
            'WiFi Sensing',
            'Passive sensing using WiFi signals for environmental awareness',
            Icons.wifi,
            () => context.push(AppRoutes.devicesWifi),
          ),
          const SizedBox(height: 16),
          _buildDeviceCard(
            context,
            'Environmental Monitoring',
            'Temperature, humidity, pressure, and air quality sensors',
            Icons.thermostat,
            () => context.push(AppRoutes.devicesEnv),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}
