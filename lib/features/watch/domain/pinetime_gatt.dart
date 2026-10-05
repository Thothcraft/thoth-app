import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// InfiniTime GATT surface (doc/ble.md, MotionService.md).
///
/// Custom services share the InfiniTime base UUID
/// ``SSSS0000-78fc-48fe-8e23-433b3a1942d0`` where SSSS is the service id.
abstract final class PinetimeGatt {
  /// UUID pattern helper — ``Guid(uuid('...'))``.
  static Guid _g(String uuid) => Guid(uuid.toLowerCase());

  // ── Device Information (0x180A) ──────────────────────────────────────────
  static final serviceDis = _g('0000180a-0000-1000-8000-00805f9b34fb');
  static final charFirmware = _g('00002a26-0000-1000-8000-00805f9b34fb');
  static final charModel = _g('00002a24-0000-1000-8000-00805f9b34fb');
  static final charManufacturer = _g('00002a29-0000-1000-8000-00805f9b34fb');

  // ── Battery (0x180F) — uint8 percent, READ + NOTIFY ──────────────────────
  static final serviceBattery = _g('0000180f-0000-1000-8000-00805f9b34fb');
  static final charBattery = _g('00002a19-0000-1000-8000-00805f9b34fb');

  // ── Heart Rate (0x180D) — measurement 0x2A37 READ + NOTIFY ──────────────
  static final serviceHr = _g('0000180d-0000-1000-8000-00805f9b34fb');
  static final charHr = _g('00002a37-0000-1000-8000-00805f9b34fb');

  // ── Motion (InfiniTime ≥1.7, service id 0003) ────────────────────────────
  static final serviceMotion = _g('00030000-78fc-48fe-8e23-433b3a1942d0');
  /// uint32 step count — READ + NOTIFY.
  static final charSteps = _g('00030001-78fc-48fe-8e23-433b3a1942d0');
  /// 3×int16 raw accel (1g = 1024) — READ + NOTIFY.
  static final charMotion = _g('00030002-78fc-48fe-8e23-433b3a1942d0');
  /// thoth-fork: x/y/z int16 + tick_ms uint32 + seq uint8 (11 B) — READ + NOTIFY.
  static final charMotionStamped =
      _g('00030003-78fc-48fe-8e23-433b3a1942d0');

  // ── Alert Notification Service (0x1811) — watch shows notifications ──────
  static final serviceAns = _g('00001811-0000-1000-8000-00805f9b34fb');
  /// WRITE: ``<category><count>\x00<utf8 data...>``.
  static final charNewAlert = _g('00002a46-0000-1000-8000-00805f9b34fb');
  /// NOTIFY: call-notification button taps — 0 declined, 1 accepted, 2 muted.
  static final charNotifEvent = _g('00020001-78fc-48fe-8e23-433b3a1942d0');

  // ── Current Time (0x1805) — write current time on connect ────────────────
  static final serviceCts = _g('00001805-0000-1000-8000-00805f9b34fb');
  static final charCurrentTime = _g('00002a2b-0000-1000-8000-00805f9b34fb');

  // ── Music (InfiniTime, service id 0000) ──────────────────────────────────
  static final serviceMusic = _g('00000000-78fc-48fe-8e23-433b3a1942d0');
  /// NOTIFY: app-open 0xe0, play 0x00, pause 0x01, next 0x03, prev 0x04, vol+ 0x05, vol- 0x06.
  static final charMusicEvent = _g('00000001-78fc-48fe-8e23-433b3a1942d0');
  /// WRITE: 0x01 playing / 0x00 paused.
  static final charMusicStatus = _g('00000002-78fc-48fe-8e23-433b3a1942d0');
  static final charMusicArtist = _g('00000003-78fc-48fe-8e23-433b3a1942d0');
  static final charMusicTrack = _g('00000004-78fc-48fe-8e23-433b3a1942d0');
  static final charMusicAlbum = _g('00000005-78fc-48fe-8e23-433b3a1942d0');

  // ── Navigation (InfiniTime, service id 0001) ─────────────────────────────
  static final serviceNav = _g('00010000-78fc-48fe-8e23-433b3a1942d0');
  static final charNavFlag = _g('00010001-78fc-48fe-8e23-433b3a1942d0');
  static final charNavNarrative = _g('00010002-78fc-48fe-8e23-433b3a1942d0');
  static final charNavDistance = _g('00010003-78fc-48fe-8e23-433b3a1942d0');
  static final charNavProgress = _g('00010004-78fc-48fe-8e23-433b3a1942d0');
}

/// One decoded accelerometer reading.
class MotionSample {
  const MotionSample(this.x, this.y, this.z, this.at,
      {this.tickMs, this.seq});

  /// g units (firmware sends binary milli-g, 1g = 1024).
  final double x, y, z;
  final DateTime at;

  /// thoth-fork: device tick (ms since boot) — absent on stock firmware.
  final int? tickMs;

  /// thoth-fork: rolling sequence for drop detection — absent on stock.
  final int? seq;
}

/// Watch telemetry snapshot pushed to UI + Brain chunk builder.
class WatchTelemetry {
  const WatchTelemetry({
    this.motion,
    this.steps,
    this.heartRate,
    this.battery,
    this.event,
    this.rssi,
    this.lat,
    this.lon,
    this.accuracyM,
    this.speedMps,
  });
  final MotionSample? motion;
  final int? steps;
  final int? heartRate;
  final int? battery;
  final String? event; // 'music:*', 'call:*' button events

  /// BLE link RSSI in dBm — phone-side proximity to the watch.
  final int? rssi;

  /// Phone GPS fix attached to this watch's trace.
  final double? lat;
  final double? lon;
  final double? accuracyM;
  final double? speedMps;
}

/// Packet codecs for InfiniTime characteristics (all little-endian).
abstract final class PinetimeCodec {
  /// ``00030002`` → accel in g (1g = 1024 binary milli-g).
  static MotionSample? decodeMotion(List<int> bytes) {
    if (bytes.length < 6) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return MotionSample(
      data.getInt16(0, Endian.little) / 1024.0,
      data.getInt16(2, Endian.little) / 1024.0,
      data.getInt16(4, Endian.little) / 1024.0,
      DateTime.now().toUtc(),
    );
  }

  /// ``00030001`` → uint32 steps.
  static int? decodeSteps(List<int> bytes) {
    if (bytes.length < 4) return null;
    return ByteData.sublistView(Uint8List.fromList(bytes))
        .getUint32(0, Endian.little);
  }

  /// ``0x2A37`` → heart-rate BPM (flag byte, then uint8/uint16 BPM).
  static int? decodeHeartRate(List<int> bytes) {
    if (bytes.length < 2) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final is16bit = (data.getUint8(0) & 0x01) != 0;
    if (is16bit && bytes.length >= 3) {
      return data.getUint16(1, Endian.little);
    }
    return data.getUint8(1);
  }

  /// ``00030003`` (thoth-fork) → 11-byte stamped accel sample.
  static MotionSample? decodeMotionStamped(List<int> bytes) {
    if (bytes.length < 11) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return MotionSample(
      data.getInt16(0, Endian.little) / 1024.0,
      data.getInt16(2, Endian.little) / 1024.0,
      data.getInt16(4, Endian.little) / 1024.0,
      DateTime.now().toUtc(),
      tickMs: data.getUint32(6, Endian.little),
      seq: data.getUint8(10),
    );
  }

  /// ``0x2A19`` → uint8 battery percent.
  static int? decodeBattery(List<int> bytes) =>
      bytes.isEmpty ? null : bytes.first.clamp(0, 100);

  /// ANS "New Alert" frame: ``<category><count>\x00<utf8 fields>``.
  /// category: 0 simple, 3 call, 5 sms… see doc/ble.md.
  static List<int> encodeAlert(int category, List<String> fields) => [
        category & 0xFF,
        0x01,
        0x00,
        ...utf8.encode(fields.join('\x00')),
      ];

  /// CTS current-time: 10-byte little-endian struct per doc/ble.md.
  static List<int> encodeCurrentTime(DateTime t) {
    final wday = t.weekday % 7; // 0 = Sunday for CTS
    final frac = ((t.millisecond * 1000 + t.microsecond) * 256 ~/ 1000000);
    return [
      t.year & 0xFF, (t.year >> 8) & 0xFF,
      t.month, t.day, t.hour, t.minute, t.second,
      wday,
      frac & 0xFF,
      0x01,
    ];
  }

  /// Music button events → readable label (notify events from watch).
  static String decodeMusicEvent(int b) => switch (b) {
        0xe0 => 'music:app_opened',
        0x00 => 'music:play',
        0x01 => 'music:pause',
        0x03 => 'music:next',
        0x04 => 'music:previous',
        0x05 => 'music:volume_up',
        0x06 => 'music:volume_down',
        _ => 'music:0x${b.toRadixString(16)}',
      };

  /// Call-notification button events (0 declined, 1 accepted, 2 muted).
  static String decodeCallEvent(int b) => switch (b) {
        0 => 'call:declined',
        1 => 'call:accepted',
        2 => 'call:muted',
        _ => 'call:0x${b.toRadixString(16)}',
      };
}
