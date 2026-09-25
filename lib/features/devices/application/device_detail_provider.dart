import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/node_client.dart';

/// Per-device state fetched through Brain's node relay (CONTRACT §5).
/// All providers are family-keyed by device_uuid and auto-dispose so the
/// detail screen never leaks polling work.

final deviceStatusProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, deviceId) {
  return NodeClient.instance.status(deviceId);
});

final deviceSensorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, deviceId) {
  return NodeClient.instance.sensors(deviceId);
});

final deviceCapturesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, deviceId) {
  return NodeClient.instance.captures(deviceId);
});

final deviceAutomationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, deviceId) {
  return NodeClient.instance.automations(deviceId);
});

final deviceMetadataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, deviceId) async {
  try {
    return await NodeClient.instance.metadata(deviceId);
  } catch (_) {
    return <String, dynamic>{}; // node may predate /api/v1/metadata
  }
});

/// Cached room/v1 doc — `{room: {...}|null, cached: bool}`.
final deviceRoomProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, deviceId) async {
  try {
    return await NodeClient.instance.room(deviceId);
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Event feed (CONTRACT §6): polls `/v1/events?device_id=&since=<id>`
/// every 15 s and yields each new batch; the screen listens and shows
/// snackbars for `trigger_fired`/`room_changed` events.
final deviceEventFeedProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, deviceId) async* {
  var lastId = '0';
  while (true) {
    try {
      final events = await NodeClient.instance
          .events(deviceId, limit: 50, since: lastId);
      if (events.isNotEmpty) {
        lastId = events.last['id']?.toString() ?? lastId;
        yield events;
      }
    } catch (_) {
      // transient failures just skip a tick
    }
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});
