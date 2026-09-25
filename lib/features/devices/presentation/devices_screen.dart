import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/devices_provider.dart';

/// Devices tab — real paired devices from Brain.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(devicesProvider.future),
        child: devices.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              Center(child: Text('Could not load devices\n$e',
                  textAlign: TextAlign.center,),),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.devices_other, size: 48),
                  const SizedBox(height: 16),
                  const Center(child: Text('No devices paired yet')),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/pair'),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Pair a device'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length + 1,
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/pair'),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Pair a device'),
                    ),
                  );
                }
                final d = list[i];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.sensors,
                      color: d.online ? Colors.green : Colors.grey,
                    ),
                    title: Text(d.name),
                    subtitle: Text(
                        '${d.deviceType ?? 'thoth'} • ${d.online ? 'online' : 'offline'}',),
                    trailing: d.batteryLevel != null
                        ? Text('${d.batteryLevel}%')
                        : null,
                    onTap: () => context.push('/devices/${d.uuid}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
