import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/watch_providers.dart';
import '../data/trace_service.dart';
import '../data/watch_link.dart';
import '../data/watch_relay.dart';
import '../data/watch_store.dart';

/// Watch tab — Gadgetbridge-style: paired watches as cards, "+" scans for
/// new InfiniTime devices. Each card shows live BLE + relay state.
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watches = ref.watch(watchListProvider);
    final relays = ref.watch(watchManagerProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(watchListProvider.notifier).refresh(),
        child: watches.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Could not load watches\n$e',
                textAlign: TextAlign.center)),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.watch, size: 56),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('No watch paired yet',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Pair a PineTime running InfiniTime.\nThe app relays its sensors to Brain.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => _openScan(context),
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan for watch'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _WatchCard(
                record: list[i],
                relay: relays[list[i].bleId],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add watch',
        onPressed: () => _openScan(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openScan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WatchScanSheet(),
    );
  }
}

class _WatchCard extends ConsumerWidget {
  const _WatchCard({required this.record, this.relay});
  final WatchRecord record;
  final WatchRelay? relay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = relay?.connected ?? false;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: connected
                  ? Colors.green.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(Icons.watch,
                  color: connected
                      ? Colors.green
                      : Theme.of(context).colorScheme.outline),
            ),
            title: Text(record.name ?? 'PineTime'),
            subtitle: Text(
              '${record.deviceUuid.length > 8 ? record.deviceUuid.substring(0, 8) : record.deviceUuid}…'
              '${relay?.firmware != null ? ' • fw ${relay!.firmware}' : ''}',
            ),
            trailing: connected
                ? ListenableBuilder(
                    listenable: TraceService.instance,
                    builder: (_, __) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _chip(Icons.bluetooth,
                            '${TraceService.instance.lastRssi ?? '—'} dBm'),
                        const SizedBox(height: 4),
                        _chip(Icons.battery_full,
                            relay?.battery != null ? '${relay!.battery}%' : '—'),
                      ],
                    ),
                  )
                : const Text('not connected',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () =>
                context.push('/watch/${Uri.encodeComponent(record.bleId)}'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                if (!connected)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Connect'),
                    onPressed: () async {
                      try {
                        await ref
                            .read(watchManagerProvider.notifier)
                            .connect(record);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connect failed: $e')));
                        }
                      }
                    },
                  )
                else
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Disconnect'),
                    onPressed: () => ref
                        .read(watchManagerProvider.notifier)
                        .disconnect(record.bleId),
                  ),
                const SizedBox(width: 12),
                if (relay?.lastError != null)
                  Expanded(
                    child: Text(relay!.lastError!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 11)),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Unpair',
                  onPressed: () async {
                    await ref
                        .read(watchManagerProvider.notifier)
                        .disconnect(record.bleId);
                    await ref
                        .read(watchListProvider.notifier)
                        .remove(record.bleId);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _chip(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
      ],
    );

/// Bottom sheet: BLE scan results → tap to pair + connect.
class WatchScanSheet extends ConsumerWidget {
  const WatchScanSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(watchScanProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scroll) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nearby watches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: results.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Scan failed: $e')),
              data: (list) {
                final watches =
                    list.where(WatchLink.looksLikeWatch).toList();
                if (watches.isEmpty) {
                  return const Center(
                      child: Text(
                          'Searching…\nMake sure the watch is awake and in range.',
                          textAlign: TextAlign.center));
                }
                return ListView.builder(
                  controller: scroll,
                  itemCount: watches.length,
                  itemBuilder: (context, i) {
                    final r = watches[i];
                    final name = r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : r.device.platformName;
                    return ListTile(
                      leading: const Icon(Icons.watch),
                      title: Text(name.isEmpty ? 'PineTime' : name),
                      subtitle: Text(
                          '${r.device.remoteId.str} • ${r.rssi} dBm'),
                      trailing: const Icon(Icons.add_link),
                      onTap: () => _pair(context, ref, r),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pair(
      BuildContext context, WidgetRef ref, ScanResult r) async {
    // Stage-aware progress + hard cap so the dialog can never spin
    // forever; Cancel dismisses the dialog (the BLE connect continues
    // in the background — pairing is idempotent server-side).
    final stage = ValueNotifier<String>('Pairing with Brain…');
    var cancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: stage,
              builder: (_, s, __) => Text(s),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(dctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    void popLocked() {
      // pairAndConnect can resolve while the dialog's route transition is
      // still animating — a synchronous pop then hits NavigatorState's
      // _debugLocked assertion and leaves a dead route (black screen).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = Navigator.of(context, rootNavigator: false);
        if (nav.canPop()) nav.pop(); // dialog
      });
    }

    try {
      await ref.read(watchManagerProvider.notifier).pairAndConnect(
        r.device.remoteId.str,
        name: r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : 'PineTime',
        onStage: (s) => stage.value =
            s == 'connecting' ? 'Connecting to watch…' : 'Pairing with Brain…',
      ).timeout(const Duration(seconds: 90), onTimeout: () {
        throw TimeoutException('still no answer — watch asleep or Brain '
            'unreachable; pairing is idempotent, try again');
      });
      if (context.mounted && !cancelled) {
        popLocked();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = Navigator.of(context, rootNavigator: false);
          if (nav.canPop()) nav.pop(); // sheet
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Watch paired — relay active')));
      }
    } catch (e) {
      if (context.mounted && !cancelled) {
        popLocked();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pairing failed: $e')));
      }
    }
  }
}
