import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

/// Owner-tagged BLE advertisement ("who is carrying this phone").
///
/// Broadcasts ``thoth-p:<owner>`` as the local name plus manufacturer
/// record ``0xFFFF + 'gad:'<owner>`` so the ESP32-C6 CSI receivers
/// (``BLE_DATA`` lines) and the Pi host scanners (``ble_scan`` samples)
/// can anchor the phone's RSSI to a person. Non-connectable, balanced
/// duty — ~1 advert/s costs negligible battery alongside the watch link.
class IdentityBeacon {
  IdentityBeacon._();
  static final IdentityBeacon instance = IdentityBeacon._();

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _enabled = false;
  String? _owner;

  bool get enabled => _enabled;

  /// Advertising service UUID — Thoth identity namespace.
  static const serviceUuid = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';

  /// Start or update the advertisement. No-op when already running with
  /// the same owner tag.
  Future<void> start({required String owner}) async {
    if (_enabled && _owner == owner) return;
    _enabled = true;
    _owner = owner;

    final supported = await _peripheral.isSupported;
    if (!supported) {
      debugPrint('[beacon] BLE advertising not supported');
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final st = await Permission.bluetoothAdvertise.request();
      if (!st.isGranted) return;
    }

    final name = 'thoth-p:$owner';
    // Keep the whole packet under 31 bytes: 'th:' + owner, truncated.
    final tag = 'th:${owner.length > 14 ? owner.substring(0, 14) : owner}';
    await _peripheral.start(
      advertiseData: AdvertiseData(
        serviceUuid: serviceUuid,
        localName: name,
        manufacturerId: 0xFFFF,
        manufacturerData: Uint8List.fromList(ascii.encode(tag)),
      ),
      advertiseSettings: AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
        connectable: false,
      ),
    );
  }

  Future<void> stop() async {
    _enabled = false;
    _owner = null;
    try {
      await _peripheral.stop();
    } catch (_) {}
  }

  /// Called whenever settings change — keeps the air interface in sync
  /// with the user's toggle without re-entering start() when nothing
  /// changed.
  Future<void> sync(bool enable, String? owner) async {
    if (enable && owner != null && owner.isNotEmpty) {
      await start(owner: owner);
    } else if (_enabled) {
      await stop();
    }
  }
}
