import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Commissioning channel contract between the app and an unprovisioned
/// node. Implemented over BLE GATT (primary) and HTTP-on-AP (recovery).
/// The node-side implementation is owned by the core agent — the UUIDs
/// and frame shapes here are the agreed surface; the app degrades to the
/// AP path or manual pairing when the BLE surface is absent.
abstract final class CommissioningContract {
  /// BLE commissioning service. "TCT" = 0x54 0x43 0x54; chars are
  /// sequence-numbered under the same prefix.
  static final serviceUuid =
      Guid('54435400-0000-1000-8000-00805f9b34fb');

  /// READ → SetupIdentity JSON {device_id, model, hw, key_hash}.
  static final charSetupIdentity =
      Guid('54435401-0000-1000-8000-00805f9b34fb');

  /// WRITE nonce (32 B) → NOTIFY signature with the setup key, proving the
  /// advertised node holds the key printed in its setup QR payload.
  static final charHandshake =
      Guid('54435402-0000-1000-8000-00805f9b34fb');

  /// WRITE {} → NOTIFY JSON array of visible SSIDs.
  static final charWifiScan =
      Guid('54435403-0000-1000-8000-00805f9b34fb');

  /// WRITE {"ssid":..,"psk":..} — PSK transits only inside the
  /// (platform-encrypted) BLE link; it is never logged or echoed back.
  static final charWifiCredentials =
      Guid('54435404-0000-1000-8000-00805f9b34fb');

  /// NOTIFY → provisioning state JSON {phase, detail?, pairing_code?}.
  static final charProvisionStatus =
      Guid('54435405-0000-1000-8000-00805f9b34fb');

  /// Advertised local-name prefix for commissioning-mode nodes.
  static const advNamePrefix = 'thoth-';

  /// Phases the node reports on the status characteristic.
  static const phaseIdle = 'idle';
  static const phaseConnecting = 'connecting';
  static const phaseJoining = 'joining_wifi';
  static const phaseVerified = 'network_verified';
  static const phaseRegistered = 'registered';
  static const phaseFailed = 'failed';

  /// AP-fallback HTTP surface (recovery mode): the node hosts these on the
  /// temporary network — same JSON as the BLE chars.
  static const apIdentityPath = '/provision/identity';
  static const apWifiPath = '/provision/wifi';
  static const apStatusPath = '/provision/status';
}

/// Decoded QR/setup-code payload: ``thoth://setup?v=1&id=<id>&k=<key>``
/// or a JSON blob with the same fields, or a bare ``key:id`` pair.
class SetupIdentity {
  const SetupIdentity({
    required this.nodeId,
    required this.setupKey,
    this.model,
    this.name,
  });

  /// Stable node identifier from the QR (``device_uuid`` once claimed).
  final String nodeId;

  /// Printed setup secret — proves the QR is physically with the device.
  final String setupKey;

  final String? model;
  final String? name;

  /// Truncated SHA-256 used to match the BLE advertisement (8 bytes hex).
  String get keyHash => sha256.convert(utf8.encode(setupKey)).toString()
      .substring(0, 16);

  static SetupIdentity? tryParse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    // JSON form: {"v":1,"id":"…","k":"…","model":"…"}
    if (s.startsWith('{')) {
      try {
        final j = Map<String, dynamic>.from(json.decode(s) as Map);
        final id = '${j['id'] ?? j['device_id'] ?? ''}';
        final k = '${j['k'] ?? j['key'] ?? j['setup_key'] ?? ''}';
        if (id.isEmpty || k.isEmpty) return null;
        return SetupIdentity(
            nodeId: id, setupKey: k,
            model: j['model']?.toString(), name: j['name']?.toString(),);
      } catch (_) {
        return null;
      }
    }
    // URI form: thoth://setup?id=…&k=…
    final uri = Uri.tryParse(s);
    if (uri != null && uri.scheme == 'thoth' && uri.host == 'setup') {
      final id = uri.queryParameters['id'] ?? '';
      final k = uri.queryParameters['k'] ?? uri.queryParameters['key'] ?? '';
      if (id.isEmpty || k.isEmpty) return null;
      return SetupIdentity(
          nodeId: id, setupKey: k,
          model: uri.queryParameters['model'], name: uri.queryParameters['name'],);
    }
    // Compact form: <id>:<key>
    final idx = s.indexOf(':');
    if (idx > 0 && idx < s.length - 1) {
      return SetupIdentity(nodeId: s.substring(0, idx),
          setupKey: s.substring(idx + 1),);
    }
    return null;
  }
}

/// Live provisioning status reported by the node (BLE notify or AP poll).
class ProvisionStatus {
  const ProvisionStatus({required this.phase, this.detail, this.pairingCode,
    this.ip, this.error,});

  final String phase;
  final String? detail;
  final String? pairingCode;
  final String? ip;
  final String? error;

  bool get isTerminalOk => phase == CommissioningContract.phaseRegistered;
  bool get isError => phase == CommissioningContract.phaseFailed;

  factory ProvisionStatus.fromJson(Map<String, dynamic> j) => ProvisionStatus(
        phase: '${j['phase'] ?? CommissioningContract.phaseIdle}',
        detail: j['detail']?.toString(),
        pairingCode: j['pairing_code']?.toString(),
        ip: j['ip']?.toString(),
        error: j['error']?.toString(),
      );
}
