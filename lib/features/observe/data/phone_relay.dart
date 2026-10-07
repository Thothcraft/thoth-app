import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/brain_client.dart';

/// Brain-side sensor ids the phone relays under — surfaced on
/// ``/v1/devices/{id}/streams/{sensor_id}`` so whispy
/// ``RemoteDevice.sensors()``/``.stream()`` sees the phone like any node.
const kPhoneSensorGps = 'phone-gps';
const kPhoneSensorImu = 'phone-imu';
const kPhoneSensorBle = 'phone-ble';

/// Phone-as-device relay: registers this handset on Brain via
/// ``POST /api/device/register`` (user token — no pairing flow needed for
/// a device the signed-in user holds), keeps it online by re-registering
/// on a heartbeat cadence, and ships sensor samples as live-chunks so the
/// whispy SDK can stream GPS/IMU/BLE like it does for nodes and watches.
///
/// Producers stay in [ObservationService] — this class only receives the
/// already-collected sightings through [submit*] calls, buffers them and
/// drains the buffer on a timer. No second BLE/GPS/IMU subscription.
class PhoneRelay {
  PhoneRelay._();
  static final PhoneRelay instance = PhoneRelay._();

  static const _kDeviceId = 'phone.device_uuid';
  static const _flushEvery = Duration(seconds: 15);
  static const _registerEvery = Duration(seconds: 60);

  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  Timer? _registerTimer;
  int _seq = 0;
  int _chunksSent = 0;
  int _chunksFailed = 0;
  bool _running = false;
  String? _deviceUuid;
  String? _deviceName;
  String? _lastError;

  int get chunksSent => _chunksSent;
  int get chunksFailed => _chunksFailed;
  String? get lastError => _lastError;
  String? get deviceUuid => _deviceUuid;
  bool get running => _running;

  /// Idempotent start. [name] is the operator-visible device name; a
  /// null/empty value falls back to ``thoth-phone``.
  Future<void> start({String? name}) async {
    if (_running) return;
    if (!BrainClient.instance.hasToken) return;
    _deviceName = (name == null || name.isEmpty) ? 'thoth-phone' : name;
    _deviceUuid ??= await _deviceId();
    _running = true;
    _flushTimer ??= Timer.periodic(_flushEvery, (_) => unawaited(_flush()));
    _registerTimer ??=
        Timer.periodic(_registerEvery, (_) => unawaited(_register()));
    unawaited(_register());
  }

  Future<void> stop() async {
    _running = false;
    _flushTimer?.cancel();
    _registerTimer?.cancel();
    _flushTimer = null;
    _registerTimer = null;
    await _flush();
  }

  // ── producers (fed by ObservationService — it owns the streams) ─────────

  void submitGps({
    required double lat,
    required double lon,
    double? accM,
    double? speedMps,
    required DateTime at,
  }) =>
      _buffer.add(
        _sample(
          kPhoneSensorGps,
          'gps',
          at,
          {
            'lat': lat,
            'lon': lon,
            if (accM != null) 'acc_m': accM,
            if (speedMps != null) 'speed_mps': speedMps,
          },
          units: {
            'lat': 'deg',
            'lon': 'deg',
            'acc_m': 'm',
            'speed_mps': 'm/s',
          },
        ),
      );

  void submitImu({
    required double x,
    required double y,
    required double z,
    required DateTime at,
  }) =>
      _buffer.add(
        _sample(
          kPhoneSensorImu,
          'imu',
          at,
          {
            'acc_x': x,
            'acc_y': y,
            'acc_z': z,
          },
          units: {
            'acc_x': 'm/s2',
            'acc_y': 'm/s2',
            'acc_z': 'm/s2',
          },
        ),
      );

  /// One BLE sighting per call — same shape the node-side radio sensors
  /// emit, so downstream consumers treat the phone as another RSSI vantage.
  void submitBleSighting({
    required String addr,
    required num rssi,
    String? name,
    bool known = false,
  }) =>
      _buffer.add(
        _sample(
          kPhoneSensorBle,
          'ble_scan',
          DateTime.now(),
          {
            'addr': addr,
            'rssi': rssi,
            if (name != null) 'name': name,
            'known': known,
          },
          units: {
            'rssi': 'dBm',
          },
        ),
      );

  // ── internals ───────────────────────────────────────────────────────────

  Map<String, dynamic> _sample(
    String sensorId,
    String sensorType,
    DateTime at,
    Map<String, dynamic> payload, {
    Map<String, String>? units,
  }) {
    return {
      'sensor_id': sensorId,
      'sensor_type': sensorType,
      'timestamp': at.millisecondsSinceEpoch / 1000.0,
      'sequence': _seq++,
      'payload': payload,
      'units': units ?? const <String, String>{},
    };
  }

  Future<String> _deviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_kDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await p.setString(_kDeviceId, id);
    }
    return id;
  }

  Future<void> _register() async {
    final uuid = _deviceUuid;
    if (uuid == null || !BrainClient.instance.hasToken) return;
    try {
      await BrainClient.instance.postJson(
        '/device/register',
        body: {
          'device_id': uuid,
          'device_name': _deviceName ?? 'thoth-phone',
          'device_type': 'phone',
          'hardware_info': {
            'transport': 'app',
            'platform': defaultTargetPlatform.name,
            'sensors': [kPhoneSensorGps, kPhoneSensorImu, kPhoneSensorBle],
          },
        },
      );
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
      debugPrint('[phone-relay] register failed: $e');
    }
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty || _deviceUuid == null) return;
    if (!BrainClient.instance.hasToken) return;
    final pending = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    final now = DateTime.now().toUtc();
    try {
      await BrainClient.instance.uploadLiveChunk(_deviceUuid!, {
        'minute': DateFormat('yyyyMMdd_HHmm').format(now),
        'second_index': now.second,
        'chunk_frames': pending.length,
        'status': 'collecting',
        'captured_at': now.toIso8601String(),
        'samples': pending,
      });
      _lastError = null;
      _chunksSent++;
    } catch (e) {
      _buffer.insertAll(0, pending);
      if (_buffer.length > 2000) {
        _buffer.removeRange(0, _buffer.length - 2000);
      }
      _lastError = '$e';
      _chunksFailed++;
      debugPrint('[phone-relay] chunk upload failed: $e');
    }
  }
}
