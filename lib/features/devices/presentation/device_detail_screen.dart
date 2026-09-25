import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/node_client.dart';
import '../application/device_detail_provider.dart';

/// Device detail — tabbed view over the node relay (status, captures,
/// automations, events). Every request flows Brain → node WS tunnel, so
/// the screen works for LAN-unreachable nodes too.
class DeviceDetailScreen extends ConsumerStatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  ProviderSubscription<AsyncValue<List<Map<String, dynamic>>>>? _eventsSub;

  String get deviceId => widget.deviceId;

  @override
  void initState() {
    super.initState();
    _eventsSub = ref.listenManual(deviceEventFeedProvider(deviceId), (_, next) {
      for (final event in next.value ?? const <Map<String, dynamic>>[]) {
        final kind = event['kind']?.toString() ?? '';
        if (!mounted) return;
        if (kind == 'trigger_fired') {
          final data = event['data'] is Map ? event['data'] as Map : const {};
          _snack('Automation fired: ${data['automation'] ?? data['name'] ?? 'trigger'}');
        } else if (kind == 'room_changed') {
          _snack('Room layout updated');
        }
      }
    });
  }

  @override
  void dispose() {
    _eventsSub?.close();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(deviceStatusProvider(deviceId));
    final offline = status.maybeWhen(
      error: (e, _) =>
          e is NodeRelayException ? e.offline : status.hasError,
      orElse: () => false,
    );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(status.valueOrNull?['name']?.toString() ?? 'Device'),
              Text(deviceId,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.circle,
                size: 12,
                color: offline
                    ? Colors.grey
                    : (status.hasValue ? Colors.green : Colors.orange),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.videocam),
              tooltip: 'Live view',
              onPressed: () => context.push('/devices/$deviceId/live'),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Captures'),
            Tab(text: 'Automations'),
            Tab(text: 'Events'),
          ]),
        ),
        body: TabBarView(children: [
          _OverviewTab(deviceId: deviceId),
          _CapturesTab(deviceId: deviceId),
          _AutomationsTab(deviceId: deviceId),
          _EventsTab(deviceId: deviceId),
        ]),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) {
    final offline = error is NodeRelayException && error.offline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          offline
              ? 'Node is offline — no tunnel to Brain.'
              : 'Failed to load: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(deviceStatusProvider(deviceId));
    final sensors = ref.watch(deviceSensorsProvider(deviceId));
    final meta = ref.watch(deviceMetadataProvider(deviceId));
    final room = ref.watch(deviceRoomProvider(deviceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(deviceStatusProvider(deviceId));
        ref.invalidate(deviceSensorsProvider(deviceId));
        ref.invalidate(deviceMetadataProvider(deviceId));
        ref.invalidate(deviceRoomProvider(deviceId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          status.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => _OfflineNote(e),
            data: (s) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _kv('State', '${s['state'] ?? 'unknown'}'),
                    _kv('Uptime',
                        s['uptime_s'] != null
                            ? '${((s['uptime_s'] as num) / 60).round()} min'
                            : '—'),
                    _kv('Active models', '${s['models_active'] ?? '—'}'),
                    _kv('Paired to cloud',
                        (s['brain'] is Map && s['brain']['paired'] == true)
                            ? 'yes'
                            : 'no'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          sensors.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sensors (${list.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final s in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${s['id']}',
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 12)),
                            ),
                            Text('${s['type'] ?? 'sensor'}',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 8),
                            Icon(Icons.circle,
                                size: 8,
                                color: s['online'] == false
                                    ? Colors.grey
                                    : Colors.green),
                          ],
                        ),
                      ),
                    if (list.isEmpty)
                      Text('No sensors reported yet.',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          meta.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (m) {
              final inferred = m['inferred'] is Map
                  ? Map<String, dynamic>.from(m['inferred'] as Map)
                  : const <String, dynamic>{};
              final battery = inferred['battery'] is Map
                  ? inferred['battery'] as Map
                  : null;
              final activity = inferred['activity'] is Map
                  ? inferred['activity'] as Map
                  : null;
              final roomDoc = room.valueOrNull?['room'];
              final roomName = roomDoc is Map
                  ? (roomDoc['name'] ?? roomDoc['room_id'])?.toString()
                  : null;
              if (battery == null && activity == null && roomName == null) {
                return const SizedBox.shrink();
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Context',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (roomName != null) _kv('Room', roomName),
                      if (battery?['percent'] != null)
                        _kv('Battery',
                            '${battery!['percent']}%${battery['charging'] == true ? ' ⚡' : ''}'),
                      if (activity?['kind'] != null)
                        _kv('Activity', '${activity!['kind']}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _CapturesTab extends ConsumerWidget {
  const _CapturesTab({required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captures = ref.watch(deviceCapturesProvider(deviceId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.fiber_manual_record, size: 16),
                label: const Text('Start capture'),
                onPressed: () async {
                  try {
                    await NodeClient.instance.startCapture(deviceId);
                    ref.invalidate(deviceCapturesProvider(deviceId));
                  } on NodeRelayException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message)));
                    }
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.invalidate(deviceCapturesProvider(deviceId)),
              ),
            ],
          ),
        ),
        Expanded(
          child: captures.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _OfflineNote(e),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No captures on this node.'));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final cap = list[i];
                  final id = '${cap['id'] ?? cap['capture_id'] ?? ''}';
                  final active = cap['state'] == 'active' ||
                      (cap['started_at'] != null && cap['stopped_at'] == null);
                  final labels = (cap['labels'] as List? ?? const [])
                      .map((l) => l is Map ? '${l['label']}' : '$l')
                      .join(', ');
                  return ListTile(
                    leading: Icon(
                      active ? Icons.fiber_manual_record : Icons.folder,
                      color: active ? Colors.red : null,
                      size: 18,
                    ),
                    title: Text(id,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13)),
                    subtitle: Text([
                      if (labels.isNotEmpty) labels,
                      'sensors: ${(cap['sensors'] as List? ?? const []).length}',
                    ].join(' · ')),
                    trailing: active
                        ? IconButton(
                            icon: const Icon(Icons.stop_circle),
                            onPressed: () async {
                              try {
                                await NodeClient.instance
                                    .stopCapture(deviceId, id);
                                ref.invalidate(
                                    deviceCapturesProvider(deviceId));
                              } on NodeRelayException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.message)));
                                }
                              }
                            },
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AutomationsTab extends ConsumerWidget {
  const _AutomationsTab({required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automations = ref.watch(deviceAutomationsProvider(deviceId));
    return automations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _OfflineNote(e),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
              child: Text('No automations on this node.\nCreate them in the portal dashboard.',
                  textAlign: TextAlign.center));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final auto = list[i];
            final id = '${auto['id']}';
            final enabled = auto['enabled'] != false;
            return SwitchListTile(
              title: Text('${auto['name'] ?? id}'),
              subtitle: Text(
                '${auto['trigger'] ?? {}} → ${auto['action'] ?? {}}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              value: enabled,
              onChanged: (v) async {
                try {
                  await NodeClient.instance
                      .toggleAutomation(deviceId, id, enabled: v);
                  ref.invalidate(deviceAutomationsProvider(deviceId));
                } on NodeRelayException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One-shot load of the recent feed; the live stream drives snackbars.
    final feed = ref.watch(deviceEventFeedProvider(deviceId));
    final seen = <String, Map<String, dynamic>>{};
    for (final batch in feed.value != null ? [feed.value!] : const []) {
      for (final e in batch) {
        seen['${e['id']}'] = e;
      }
    }
    final events = seen.values.toList()
      ..sort((a, b) =>
          (num.tryParse('${b['id']}') ?? 0)
              .compareTo(num.tryParse('${a['id']}') ?? 0));

    if (events.isEmpty) {
      return Center(
        child: feed.isLoading
            ? const CircularProgressIndicator()
            : const Text('No events yet — triggers and room changes land here.'),
      );
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        final ts = e['ts'] is num ? (e['ts'] as num).toDouble() : 0.0;
        final when = ts > 0
            ? DateTime.fromMillisecondsSinceEpoch((ts * 1000).round())
                .toLocal()
                .toString()
                .substring(11, 19)
            : '';
        return ListTile(
          dense: true,
          leading: Icon(
            e['kind'] == 'trigger_fired'
                ? Icons.bolt
                : e['kind'] == 'room_changed'
                    ? Icons.meeting_room
                    : Icons.info_outline,
            size: 18,
          ),
          title: Text('${e['kind']}', style: const TextStyle(fontSize: 13)),
          subtitle: Text('$when',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        );
      },
    );
  }
}
