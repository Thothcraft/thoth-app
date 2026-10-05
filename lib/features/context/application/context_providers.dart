import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../context/data/context_repository.dart';
import '../../context/domain/models.dart';
import '../../devices/application/devices_provider.dart';

/// One-shot repository accessor for imperative calls.
final contextRepoProvider =
    Provider<ContextRepository>((_) => ContextRepository());

/// Polling cadence — matches the Brain event feed contract (≤30 s).
const _pollCadence = Duration(seconds: 15);

/// Live context snapshot — entities + valid relationships + active
/// states. Polls on a cadence; the provider is kept alive while the
/// context tab is visible.
final contextSnapshotProvider =
    StreamProvider.autoDispose<ContextSnapshot>((ref) async* {
  final repo = ref.watch(contextRepoProvider);
  for (;;) {
    yield await repo.snapshot();
    await Future<void>.delayed(_pollCadence);
  }
});

/// Spaces with their live occupancy merged in.
final spacesLiveProvider =
    StreamProvider.autoDispose<List<SpaceInfo>>((ref) async* {
  final repo = ref.watch(contextRepoProvider);
  for (;;) {
    final spaces = await repo.spaces();
    Map<int, SpaceInfo> states = const {};
    try {
      states = await repo.spacesState();
    } catch (_) {/* state endpoint may lag creation */}
    yield spaces.map((s) {
      final live = states[s.id];
      return live == null
          ? s
          : SpaceInfo(
              id: s.id,
              name: s.name,
              parentId: s.parentId,
              widthM: s.widthM,
              heightM: s.heightM,
              zones: s.zones,
              placements: s.placements,
              occupied: live.occupied,
              peopleCount: live.peopleCount,
              occupancyConfidence: live.occupancyConfidence,
              zoneStates: live.zoneStates,
              lastActivity: live.lastActivity ?? s.lastActivity,
            );
    }).toList();
    await Future<void>.delayed(_pollCadence);
  }
});

/// Recent semantic events (transitions), newest first.
final contextEventsProvider =
    StreamProvider.autoDispose<List<ContextEvent>>((ref) async* {
  final repo = ref.watch(contextRepoProvider);
  for (;;) {
    yield await repo.events(limit: 100);
    await Future<void>.delayed(_pollCadence);
  }
});

/// All current states for one entity — the person page's context card.
final entityStatesProvider =
    FutureProvider.autoDispose.family<List<ContextState>, String>(
        (ref, entityId) =>
            ref.watch(contextRepoProvider).states(entityId: entityId));

/// Recent evidence touching an entity (via provenance) or a key.
final entityEvidenceProvider =
    FutureProvider.autoDispose.family<List<ContextEvidence>, String>(
        (ref, entityId) async {
  final repo = ref.watch(contextRepoProvider);
  final all = await repo.evidence(limit: 300);
  return all
      .where((e) =>
          e.provenance['entity'] == entityId ||
          e.provenance['entity_id'] == entityId ||
          e.deviceId == entityId ||
          '${e.value}'.contains(entityId))
      .toList();
});

/// Events for one entity — the person page's history.
final entityEventsProvider =
    FutureProvider.autoDispose.family<List<ContextEvent>, String>(
        (ref, entityId) async {
  final all = await ref.watch(contextRepoProvider).events(limit: 300);
  return all.where((e) => e.entityId == entityId).toList();
});

/// BLE proximity evidence → observer→target edges for the relation graph.
final bleRelationsProvider =
    StreamProvider.autoDispose<List<BleRelation>>((ref) async* {
  final repo = ref.watch(contextRepoProvider);
  for (;;) {
    final rows = await repo.evidence(
        key: ContextKeys.bleProximityEvidence, limit: 500);
    // Keep the freshest edge per (observer, target).
    final byKey = <String, BleRelation>{};
    for (final e in rows) {
      final v = e.value is Map ? Map<String, dynamic>.from(e.value) : null;
      if (v == null) continue;
      final observer = '${v['observer'] ?? e.sourceId ?? 'unknown'}';
      final target = '${v['target'] ?? ''}';
      final rssi = (v['rssi_dbm'] as num?)?.toDouble() ??
          (v['rssi'] as num?)?.toDouble();
      if (target.isEmpty || rssi == null) continue;
      final key = '$observer→$target';
      final existing = byKey[key];
      final ts = e.timestamp ?? 0;
      if (existing == null || ts > existing.timestamp) {
        byKey[key] = BleRelation(
          observer: observer,
          target: target,
          rssiDbm: rssi,
          timestamp: ts,
          count: (existing?.count ?? 0) + 1,
          confidence: e.confidence,
          rssiWindow: [
            ...?existing?.rssiWindow,
            rssi,
          ].reversed.take(12).toList().reversed.toList(),
        );
      } else {
        byKey[key] = existing.copyWith(count: existing.count + 1);
      }
    }
    yield byKey.values.toList();
    await Future<void>.delayed(_pollCadence);
  }
});

class BleRelation {
  const BleRelation({
    required this.observer,
    required this.target,
    required this.rssiDbm,
    required this.timestamp,
    this.count = 1,
    this.confidence,
    this.rssiWindow = const [],
  });

  final String observer;
  final String target;
  final double rssiDbm;
  final double timestamp;
  final int count;
  final double? confidence;

  /// Recent RSSI samples for this edge (oldest→newest, ≤12).
  final List<double> rssiWindow;

  /// Age in seconds — freshness coloring on the graph edge.
  double get ageSeconds =>
      DateTime.now().millisecondsSinceEpoch / 1000 - timestamp;

  /// RSSI spread across the window — > 4 dB means the radio link is
  /// physically changing (someone/something moved). Honest label: it's
  /// signal variance, not a motion classifier.
  bool get moving {
    if (rssiWindow.length < 3) return false;
    final lo = rssiWindow.reduce(math.min);
    final hi = rssiWindow.reduce(math.max);
    return hi - lo > 4;
  }

  double get rssiSpreadDb => rssiWindow.length < 2
      ? 0
      : rssiWindow.reduce(math.max) - rssiWindow.reduce(math.min);

  BleRelation copyWith({int? count}) => BleRelation(
      observer: observer,
      target: target,
      rssiDbm: rssiDbm,
      timestamp: timestamp,
      count: count ?? this.count,
      confidence: confidence,
      rssiWindow: rssiWindow);
}

/// Owned devices (for claim/space pickers in setup).
final deviceListProvider = devicesProvider;
