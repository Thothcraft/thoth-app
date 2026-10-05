import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../observe/data/observation_service.dart';
import '../../settings/application/app_settings.dart';
import '../data/trace_service.dart';
import '../data/watch_link.dart';
import '../data/watch_relay.dart';
import '../data/watch_store.dart';
import '../domain/pinetime_gatt.dart';

/// Paired watches persisted in secure storage.
final watchListProvider =
    AsyncNotifierProvider<WatchListNotifier, List<WatchRecord>>(
        WatchListNotifier.new);

class WatchListNotifier extends AsyncNotifier<List<WatchRecord>> {
  @override
  Future<List<WatchRecord>> build() => WatchStore.instance.load();

  Future<void> refresh() async {
    state = AsyncData(await WatchStore.instance.load());
  }

  Future<void> remove(String bleId) async {
    await WatchStore.instance.remove(bleId);
    await refresh();
  }
}

/// Live connection/telemetry manager — one relay per paired watch.
final watchManagerProvider =
    NotifierProvider<WatchManager, Map<String, WatchRelay>>(WatchManager.new);

class WatchManager extends Notifier<Map<String, WatchRelay>> {
  /// Watch-scan telemetry forwarding — one sub per connected link.
  final Map<String, StreamSubscription<WatchTelemetry>> _scanSubs = {};

  @override
  Map<String, WatchRelay> build() {
    ref.onDispose(() {
      for (final relay in state.values) {
        relay.dispose();
      }
      for (final sub in _scanSubs.values) {
        sub.cancel();
      }
    });
    ref.listen(watchListProvider, (_, next) {
      final watches = next.value ?? const <WatchRecord>[];
      // Dispose relays for watches that were unpaired.
      for (final key in state.keys.toList()) {
        if (!watches.any((w) => w.bleId == key)) {
          _scanSubs.remove(key)?.cancel();
          state[key]?.dispose();
          state = {...state}..remove(key);
        }
      }
    });
    // Settings toggles apply live to the trace/background service.
    ref.listen(appSettingsProvider, (_, next) {
      final s = next.value;
      if (s == null) return;
      unawaited(TraceService.instance.setBackgroundRelay(s.backgroundRelay));
      unawaited(TraceService.instance.setGpsTrace(s.gpsTrace));
    });
    return {};
  }

  WatchRelay? relayFor(String bleId) => state[bleId];

  /// Connect (or reuse) the BLE link and start the Brain relay.
  Future<WatchRelay> connect(WatchRecord record) async {
    final existing = state[record.bleId];
    if (existing != null && existing.connected) return existing;
    await existing?.dispose();

    final device = BluetoothDevice.fromId(record.bleId);
    final link = WatchLink(device);
    // Bounded: WatchLink's connect loop retries forever by design for
    // reconnects, but a pairing-time connect must fail fast or the
    // "Pairing with Brain" dialog hangs with no feedback.
    await link.connect().timeout(const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
            'watch unreachable — keep it awake and in range'));

    final relay = WatchRelay(record);
    await relay.start(link);
    state = {...state, record.bleId: relay};
    // Watch-side neighbor scan → Brain proximity evidence with the
    // watch as observer — the wrist-level viewpoint the map needs to
    // triangulate devices the phone itself can't hear.
    _scanSubs[record.bleId]?.cancel();
    _scanSubs[record.bleId] = link.telemetry.listen((t) {
      final scan = t.bleScan;
      if (scan != null && scan.isNotEmpty) {
        ObservationService.instance.submitWatchSightings(
            observer: record.deviceUuid, sightings: scan);
      }
    });
    // Foreground service + GPS/RSSI trace — keeps IMU streaming with the
    // screen off and feeds pinetime-prox / pinetime-gps into Brain.
    final s = ref.read(appSettingsProvider).valueOrNull ??
        const AppSettings();
    unawaited(TraceService.instance.attach(relay,
        backgroundRelay: s.backgroundRelay, gpsTrace: s.gpsTrace));
    // First connect ever: ask for the doze exemption. FGS + wakelock keep
    // the process alive, but only the whitelist keeps uploads flowing when
    // the phone sits unplugged and still for a long stretch.
    if (!s.batteryOptPrompted) {
      await ref.read(appSettingsProvider.notifier).setBatteryOptPrompted();
      unawaited(
          TraceService.instance.requestBatteryOptimizationExemption());
    }
    return relay;
  }

  /// Pair + connect a newly scanned watch in one shot. [onStage]
  /// reports progress ('pairing' → 'connecting') for the dialog.
  Future<WatchRecord> pairAndConnect(String bleId,
      {String? name, void Function(String stage)? onStage}) async {
    onStage?.call('pairing');
    final record = await WatchRelay.pair(bleId, name: name);
    await WatchStore.instance.upsert(record);
    await ref.read(watchListProvider.notifier).refresh();
    onStage?.call('connecting');
    await connect(record);
    return record;
  }

  Future<void> disconnect(String bleId) async {
    await _scanSubs.remove(bleId)?.cancel();
    await state[bleId]?.dispose();
    state = {...state}..remove(bleId);
    if (state.isEmpty) await TraceService.instance.detach();
  }
}

/// BLE scan results filtered to InfiniTime/PineTime advertisers.
final watchScanProvider =
    StreamProvider.autoDispose<List<ScanResult>>((ref) => WatchLink.scan());

/// Latest telemetry per watch (broadcast, replayed to late listeners).
final watchTelemetryProvider = StreamProvider.autoDispose
    .family<WatchTelemetry, String>((ref, bleId) {
  final relay = ref.watch(watchManagerProvider)[bleId];
  return relay?.telemetry ?? const Stream.empty();
});

/// Connection state per watch.
final watchConnectionProvider = StreamProvider.autoDispose
    .family<BluetoothConnectionState, String>((ref, bleId) {
  final relay = ref.watch(watchManagerProvider)[bleId];
  return relay?.link?.connection ?? const Stream.empty();
});
