import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/brain_client.dart';

class ThothDevice {
  const ThothDevice({
    required this.uuid,
    required this.name,
    required this.online,
    this.deviceType,
    this.batteryLevel,
    this.lastSeen,
  });

  final String uuid;
  final String name;
  final bool online;
  final String? deviceType;
  final int? batteryLevel;
  final String? lastSeen;

  factory ThothDevice.fromJson(Map<String, dynamic> json) => ThothDevice(
        uuid: (json['device_uuid'] ?? json['device_id'] ?? '').toString(),
        name: (json['device_name'] ?? json['name'] ?? 'Device').toString(),
        online: json['online'] == true || json['is_online'] == true,
        deviceType: json['device_type']?.toString(),
        batteryLevel: json['battery_level'] is int
            ? json['battery_level'] as int
            : int.tryParse('${json['battery_level']}'),
        lastSeen: json['last_seen']?.toString(),
      );
}

final devicesProvider = FutureProvider<List<ThothDevice>>((ref) async {
  final client = BrainClient.instance;
  final payload = await client.getJson('/device/list');
  final items = (payload['devices'] ?? payload['data'] ?? []) as List;
  return items
      .map((e) => ThothDevice.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});
