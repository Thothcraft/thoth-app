import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/brain_client.dart';
import '../../auth/application/auth_provider.dart';

final _labsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final payload = await BrainClient.instance.getJson('/labs');
  return (payload['labs'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

/// Research tab — Labs catalog gated on the labs entitlement.
class ResearchScreen extends ConsumerWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (!auth.hasEntitlement('labs') && auth.plan != 'research') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.science, size: 48),
                const SizedBox(height: 16),
                Text('Research Labs',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Labs are available on the Research plan — '
                  'reproducible experiments with notebook grading.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final labs = ref.watch(_labsProvider);
    return Scaffold(
      body: labs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load labs\n$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No labs published yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final lab = list[i];
                  final sub = lab['my_submission'] as Map?;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.science),
                      title: Text(lab['title']?.toString() ?? 'Lab'),
                      subtitle: Text(
                          '${lab['track_title'] ?? lab['track'] ?? ''} • ${lab['level'] ?? ''}'),
                      trailing: sub == null
                          ? const Icon(Icons.chevron_right)
                          : Icon(
                              sub['passed'] == true
                                  ? Icons.check_circle
                                  : Icons.hourglass_top,
                              color: sub['passed'] == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
