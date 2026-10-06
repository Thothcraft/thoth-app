import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../devices/application/devices_provider.dart';
import '../application/context_providers.dart';
import '../domain/models.dart';

/// Space detail — the in-app twin of a designed space on the portal.
///
/// Surfaces live occupancy (presence evidence fused by Brain), the
/// zones inside the space, devices placed into it, people currently
/// located here, and the recent movement involving the space.
class SpaceDetailScreen extends ConsumerWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesAsync = ref.watch(spacesLiveProvider);
    final snapAsync = ref.watch(contextSnapshotProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final eventsAsync = ref.watch(contextEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Space')),
      body: spacesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Space unavailable: $e')),
        data: (spaces) {
          SpaceInfo? space;
          for (final s in spaces) {
            if ('${s.id}' == spaceId) {
              space = s;
              break;
            }
          }
          if (space == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sensor_door_outlined,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Space "$spaceId" was not found.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                        'It may have been deleted on the portal, or the '
                        'spaces feed has not synced yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final sp = space;
          final devices = devicesAsync.valueOrNull ?? const [];
          final snap = snapAsync.valueOrNull;
          final events = eventsAsync.valueOrNull ?? const [];

          // Devices placed into this space (portal placements).
          final placed = <ThothDevice>[
            for (final d in devices)
              if (sp.placements.any((p) => '${p['device_id']}' == d.uuid)) d,
          ];
          final unlinked = sp.placements
              .where((p) => '${p['device_id']}'.isNotEmpty &&
                  !placed.any((d) => d.uuid == '${p['device_id']}'))
              .toList();

          // Entities whose active location state points here.
          final hereIds = <String>{};
          for (final st in snap?.states ?? const <ContextState>[]) {
            if (st.key != 'location.space.v1' || !st.active) continue;
            if (_stateMatchesSpace(st.value, sp)) {
              hereIds.add(st.entityId);
            }
          }
          final here = <ContextEntity>[
            for (final e in snap?.entities ?? const <ContextEntity>[])
              if (hereIds.contains(e.id)) e,
          ];

          // Recent movement touching this space.
          final moves =
              events.where((e) => _eventMatches(e, sp)).take(10).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(spacesLiveProvider);
              ref.invalidate(contextSnapshotProvider);
              ref.invalidate(contextEventsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(space: sp, peopleHere: here.length),
                const SizedBox(height: 12),
                if (sp.zones.isNotEmpty) ...[
                  _ZonesCard(space: sp),
                  const SizedBox(height: 12),
                ],
                _DevicesCard(placed: placed, unlinked: unlinked),
                const SizedBox(height: 12),
                if (here.isNotEmpty) ...[
                  _PeopleCard(entities: here),
                  const SizedBox(height: 12),
                ],
                _MovesCard(events: moves),
              ],
            ),
          );
        },
      ),
    );
  }

  /// A location state value can be a bare string ("office"), a map
  /// ({space: office}), or an id — accept any shape pointing at [s].
  static bool _stateMatchesSpace(dynamic v, SpaceInfo s) {
    if (v == null) return false;
    String name(String? x) => (x ?? '').toLowerCase();
    if (v is String) {
      return v == '${s.id}' || name(v) == name(s.name);
    }
    if (v is Map) {
      for (final k in const ['space', 'space_id', 'name', 'id']) {
        final x = v[k];
        if (x == null) continue;
        if ('$x' == '${s.id}' || name('$x') == name(s.name)) return true;
      }
    }
    return false;
  }

  static bool _eventMatches(ContextEvent e, SpaceInfo s) {
    bool hit(dynamic v) {
      if (v == null) return false;
      final str = '$v'.toLowerCase();
      return str.contains('${s.id}') ||
          str.contains(s.name.toLowerCase());
    }

    return hit(e.value) || hit(e.previousValue);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.space, required this.peopleHere});
  final SpaceInfo space;
  final int peopleHere;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dims = [
      if ((space.widthM ?? 0) > 0) space.widthM!.toStringAsFixed(1),
      if ((space.heightM ?? 0) > 0) space.heightM!.toStringAsFixed(1),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: space.occupied
                  ? Colors.green.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              space.occupied
                  ? Icons.sensor_door
                  : Icons.sensor_door_outlined,
              size: 34,
              color: space.occupied ? Colors.green : cs.outline,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(space.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  space.occupied
                      ? 'Occupied'
                      : space.occupancyConfidence > 0
                          ? 'Possibly occupied'
                          : 'Empty',
                  style: TextStyle(
                      color: space.occupied ? Colors.green : cs.outline,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '$peopleHere here',
                    '${space.placements.length} placed',
                    if (dims.length == 2) '${dims[0]}×${dims[1]} m',
                    if (space.occupancyConfidence > 0)
                      '${(space.occupancyConfidence * 100).round()}% conf',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ZonesCard extends StatelessWidget {
  const _ZonesCard({required this.space});
  final SpaceInfo space;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zones', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final z in space.zones)
                  Builder(builder: (_) {
                    final zid = '${z['id'] ?? z['name'] ?? ''}';
                    final st = space.zoneStates[zid];
                    final occ = st?['occupied'] == true ||
                        ((st?['occupancy'] as num?) ?? 0) > 0;
                    final conf = (st?['confidence'] as num?) ??
                        (st?['occupancy'] as num?) ??
                        0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: occ
                            ? Colors.green.withValues(alpha: 0.12)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(occ ? Icons.circle : Icons.circle_outlined,
                            size: 10,
                            color: occ ? Colors.green : Colors.grey),
                        const SizedBox(width: 6),
                        Text('${z['name'] ?? zid}',
                            style: const TextStyle(fontSize: 13)),
                        if (conf > 0) ...[
                          const SizedBox(width: 6),
                          Text('${(conf * 100).round()}%',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ]),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.placed, required this.unlinked});
  final List<ThothDevice> placed;
  final List<Map<String, dynamic>> unlinked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devices in this space',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (placed.isEmpty && unlinked.isEmpty)
              const Text(
                  'No devices placed here yet — place them on the space '
                  'in the portal and they will appear here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            for (final d in placed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    (d.deviceType ?? '').contains('watch')
                        ? Icons.watch
                        : Icons.router,
                    color: d.online ? Colors.green : Colors.grey),
                title: Text(d.name),
                subtitle: Text(d.online ? 'online' : 'offline',
                    style: const TextStyle(fontSize: 12)),
                onTap: () => context.push('/devices/${d.uuid}'),
              ),
            for (final p in unlinked)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bluetooth, color: Colors.grey),
                title: Text('${p['device_name'] ?? p['device_id']}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    'placed at ${((p['x'] as num?) ?? 0).toStringAsFixed(1)},'
                    '${((p['y'] as num?) ?? 0).toStringAsFixed(1)} m'
                    '${p['floor'] != null ? ' · ${p['floor']}' : ''}',
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.entities});
  final List<ContextEntity> entities;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Here now',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in entities)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    e.kind == 'person'
                        ? Icons.person
                        : Icons.category_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: Text((e.name?.isNotEmpty ?? false) ? e.name! : e.id),
                subtitle:
                    Text(e.kind, style: const TextStyle(fontSize: 12)),
                onTap: () =>
                    context.push('/context/entities/${e.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovesCard extends StatelessWidget {
  const _MovesCard({required this.events});
  final List<ContextEvent> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent activity here',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Text('No movement recorded for this space yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        e.type == 'exited'
                            ? Icons.south_east
                            : Icons.north_east,
                        size: 14,
                        color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${e.entityId?.split(':').last ?? 'entity'} '
                        '${e.type} ${_val(e.value)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(_ago(e.timestamp),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _val(dynamic v) {
    if (v is Map) return '${v['space'] ?? v['space_id'] ?? v}';
    return '$v';
  }

  static String _ago(double? ts) {
    if (ts == null) return '';
    final d = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch((ts * 1000).round()));
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
