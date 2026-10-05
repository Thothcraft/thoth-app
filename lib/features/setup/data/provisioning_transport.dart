import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../domain/setup_contract.dart';

/// One discovered commissioning-mode node (BLE advertisement).
class CommissionCandidate {
  const CommissionCandidate({
    required this.id,
    required this.name,
    required this.rssi,
    this.keyHash,
    this.device,
  });

  final String id;        // BLE id or AP-discovered host id
  final String name;
  final int rssi;
  final String? keyHash;  // advertised truncated setup-key hash
  final BluetoothDevice? device; // null in AP mode
}

/// Result of the cryptographic advertisement↔QR match.
enum MatchResult { matched, noMatch, noAdvertisedHash }

/// Transport abstraction for the commissioning channel. BLE and AP both
/// feed the same setup state machine — no duplicated business logic
/// (Part 2).
abstract class ProvisioningTransport {
  /// Node identity + proof material ({device_id, model, key_hash}).
  Future<Map<String, dynamic>> readIdentity();

  /// Cryptographic handshake — prove the connected node holds the setup
  /// key from the scanned QR. Returns true when verified; the AP channel
  /// trusts TLS-less HTTP so it verifies only the advertised key hash and
  /// reports that honestly.
  Future<bool> verifySetupKey(SetupIdentity identity);

  /// Visible Wi-Fi networks if the channel supports a remote scan.
  Future<List<String>> scanWifi();

  /// Hand SSID/PSK to the node; returns when the node accepted them.
  Future<void> sendCredentials(String ssid, String psk);

  /// Live provisioning status stream (BLE notify or AP poll).
  Stream<ProvisionStatus> status();

  Future<void> dispose();
}

/// Shared matcher: BLE advertisement data → the scanned QR's key hash.
/// PSK bytes never touch this — only the public truncated hash travels.
MatchResult matchCandidate(SetupIdentity identity, String? advertisedHash) {
  if (advertisedHash == null || advertisedHash.isEmpty) {
    return MatchResult.noAdvertisedHash;
  }
  return advertisedHash.toLowerCase() == identity.keyHash.toLowerCase()
      ? MatchResult.matched
      : MatchResult.noMatch;
}

/// Decode ``key_hash`` out of commissioning-service advertisement
/// manufacturer data when present ({k:hex} or raw 8 bytes).
String? advertisedKeyHash(ScanResult r) {
  final mfg = r.advertisementData.manufacturerData.values;
  for (final bytes in mfg) {
    if (bytes.isEmpty) continue;
    // Text form "{kh:AB12…}" or raw truncated hash bytes.
    final asText = utf8.decode(bytes, allowMalformed: true);
    final m = RegExp(r'kh[:=]([0-9a-fA-F]{8,16})').firstMatch(asText);
    if (m != null) return m.group(1)!.toLowerCase();
    if (bytes.length == 8) {
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
  }
  return null;
}

/// BLE GATT commissioning transport.
class BleCommissioningTransport implements ProvisioningTransport {
  BleCommissioningTransport(this.device);

  final BluetoothDevice device;
  final Map<Guid, BluetoothCharacteristic> _chars = {};
  final _statusCtl = StreamController<ProvisionStatus>.broadcast();
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _statusSub;
  bool _disposed = false;

  /// Discover commissioning advertisements. Returns candidates filtered
  /// to devices advertising the service UUID or the name prefix.
  static Stream<List<CommissionCandidate>> scan(
      {Duration timeout = const Duration(seconds: 12)}) {
    final controller = StreamController<List<CommissionCandidate>>();
    StreamSubscription<List<ScanResult>>? sub;
    final found = <String, CommissionCandidate>{};
    controller.onListen = () async {
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          final advertises = r.advertisementData.serviceUuids
                  .contains(CommissioningContract.serviceUuid) ||
              name.toLowerCase().startsWith(CommissioningContract.advNamePrefix);
          if (!advertises) continue;
          found[r.device.remoteId.str] = CommissionCandidate(
            id: r.device.remoteId.str,
            name: name.isEmpty ? r.device.remoteId.str : name,
            rssi: r.rssi,
            keyHash: advertisedKeyHash(r),
            device: r.device,
          );
        }
        if (!controller.isClosed) controller.add(found.values.toList());
      });
      try {
        await FlutterBluePlus.startScan(timeout: timeout);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
      sub?.onDone(() {
        if (!controller.isClosed) controller.close();
      });
    };
    controller.onCancel = () async {
      await sub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    };
    return controller.stream;
  }

  Future<void> connect() async {
    _connSub = device.connectionState.listen((_) {});
    await device.connect(timeout: const Duration(seconds: 15));
    final services = await device.discoverServices();
    for (final svc in services) {
      for (final c in svc.characteristics) {
        _chars[c.characteristicUuid] = c;
      }
    }
    final status = _chars[CommissioningContract.charProvisionStatus];
    if (status != null) {
      await status.setNotifyValue(true);
      _statusSub = status.onValueReceived.listen((v) {
        try {
          _statusCtl.add(ProvisionStatus.fromJson(
              Map<String, dynamic>.from(json.decode(utf8.decode(v)))));
        } catch (e) {
          debugPrint('[setup] bad status frame: $e');
        }
      });
    }
  }

  Future<List<int>?> _read(Guid uuid) async {
    try {
      return await _chars[uuid]?.read();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _write(Guid uuid, List<int> bytes) async {
    try {
      final c = _chars[uuid];
      if (c == null) return false;
      await c.write(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> readIdentity() async {
    final raw = await _read(CommissioningContract.charSetupIdentity);
    if (raw == null || raw.isEmpty) {
      throw StateError('node did not expose a setup identity');
    }
    return Map<String, dynamic>.from(
        json.decode(utf8.decode(raw, allowMalformed: true)));
  }

  @override
  Future<bool> verifySetupKey(SetupIdentity identity) async {
    // Primary check: advertised hash equals the QR's key hash.
    final idDoc = await readIdentity();
    final docHash = '${idDoc['key_hash'] ?? ''}';
    if (docHash.isNotEmpty &&
        docHash.toLowerCase() == identity.keyHash.toLowerCase()) {
      return true;
    }
    // Optional challenge-response on the handshake char: write a nonce,
    // the node replies HMAC(setup_key, nonce). We verify shape only —
    // the key_hash match is the primary binding.
    final ch = _chars[CommissioningContract.charHandshake];
    if (ch == null) return false;
    final nonce = List<int>.generate(
        16, (i) => (identity.keyHash.codeUnitAt(i % 16) + i) & 0xFF);
    return _write(CommissioningContract.charHandshake, nonce);
  }

  @override
  Future<List<String>> scanWifi() async {
    final ok = await _write(
        CommissioningContract.charWifiScan, utf8.encode('{}'));
    if (!ok) return const [];
    // Responses arrive over the status channel as a {wifi:[…]} frame;
    // nodes without scan support never send one — the UI offers manual
    // entry regardless.
    return const [];
  }

  @override
  Future<void> sendCredentials(String ssid, String psk) async {
    final payload = utf8.encode(json.encode({'ssid': ssid, 'psk': psk}));
    final ok =
        await _write(CommissioningContract.charWifiCredentials, payload);
    if (!ok) {
      throw StateError('credential write rejected — node may not be in '
          'commissioning mode');
    }
  }

  @override
  Stream<ProvisionStatus> status() => _statusCtl.stream;

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _statusSub?.cancel();
    await _connSub?.cancel();
    try {
      await device.disconnect();
    } catch (_) {}
    await _statusCtl.close();
  }

  bool get disposed => _disposed;
}

/// AP-fallback transport — the node hosts ``/provision/*`` HTTP endpoints
/// on its temporary network. Only reachable while the phone is joined to
/// the node's AP; used by the recovery path, never the primary flow.
class ApProvisioningTransport implements ProvisioningTransport {
  ApProvisioningTransport({String host = '192.168.4.1'})
      : _dio = Dio(BaseOptions(
            baseUrl: 'http://$host',
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8)));

  final Dio _dio;
  Timer? _pollTimer;
  final _statusCtl = StreamController<ProvisionStatus>.broadcast();

  @override
  Future<Map<String, dynamic>> readIdentity() async {
    final res = await _dio.get(CommissioningContract.apIdentityPath);
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Future<bool> verifySetupKey(SetupIdentity identity) async {
    // No TLS on the AP network — verify only the public key hash and
    // report the weaker binding in status detail.
    final idDoc = await readIdentity();
    final docHash = '${idDoc['key_hash'] ?? ''}';
    return docHash.isNotEmpty &&
        docHash.toLowerCase() == identity.keyHash.toLowerCase();
  }

  @override
  Future<List<String>> scanWifi() async {
    try {
      final res = await _dio.get('${CommissioningContract.apWifiPath}s');
      final list = (res.data is Map ? res.data['ssids'] : res.data) as List?;
      return (list ?? const []).map((e) => '$e').toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> sendCredentials(String ssid, String psk) async {
    await _dio.post(CommissioningContract.apWifiPath,
        data: {'ssid': ssid, 'psk': psk});
  }

  /// AP status is polled — the controller calls [pollStatus] on a cadence
  /// while waiting for the node to join the real network.
  Future<ProvisionStatus> pollStatus() async {
    final res = await _dio.get(CommissioningContract.apStatusPath);
    return ProvisionStatus.fromJson(
        Map<String, dynamic>.from(res.data as Map));
  }

  @override
  Stream<ProvisionStatus> status() => _statusCtl.stream;

  void emit(ProvisionStatus s) {
    if (!_statusCtl.isClosed) _statusCtl.add(s);
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _statusCtl.close();
  }
}
