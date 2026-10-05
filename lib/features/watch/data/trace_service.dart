import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/pinetime_gatt.dart';
import 'watch_relay.dart';

/// One point on the movement trace — phone GPS stamped with the current
/// BLE link strength to the watch (phone-proximity indicator).
class TracePoint {
  const TracePoint({
    required this.at,
    required this.lat,
    required this.lon,
    this.accuracyM,
    this.speedMps,
    this.rssi,
  });

  final DateTime at;
  final double lat;
  final double lon;
  final double? accuracyM;
  final double? speedMps;
  final int? rssi;
}

/// Phone-side sensor collector for the watch relay.
///
/// With the screen off Android kills backgrounded apps that hold a BLE
/// link, so [attach] starts a `connectedDevice|location` foreground
/// service (persistent notification) plus a wakelock — the whole Dart
/// isolate stays alive and BLE notifications, flush/heartbeat timers and
/// the GPS stream keep running.
///
/// [foregroundServiceOn] and [gpsTraceOn] are driven by app settings and
/// can be toggled live; the rest (RSSI poll, trace buffer) always runs
/// while a watch is connected.
class TraceService extends ChangeNotifier {
  TraceService._();
  static final TraceService instance = TraceService._();

  static const _maxTrace = 5000;
  static const _emaAlpha = 0.35; // RSSI smoothing
  static const _dropAccuracyM = 25.0; // fixes worse than this are skipped
  static const _minStepM = 1.5; // fixes closer than this are merged

  final List<TracePoint> trace = [];
  final _traceOut = StreamController<TracePoint>.broadcast();

  WatchRelay? _relay;
  Timer? _rssiTimer;
  Timer? _diagTimer;
  StreamSubscription<Position>? _posSub;
  bool _fgsRunning = false;
  bool _fgInited = false;
  bool _backgroundOn = true;
  bool _gpsOn = true;
  bool _permitted = false;

  int? _lastRssi;
  double? _rssiSmooth;
  Position? _lastFix;
  TracePoint? _lastKept;
  double _distanceM = 0;
  bool _batteryOptAsked = false;

  Stream<TracePoint> get points => _traceOut.stream;
  bool get relayAttached => _relay != null;
  bool get foregroundServiceRunning => _fgsRunning;
  int? get lastRssi => _lastRssi;
  double? get rssiSmooth => _rssiSmooth;
  Position? get lastFix => _lastFix;
  double get distanceM => _distanceM;
  DateTime? get firstPointAt => trace.isEmpty ? null : trace.first.at;

  /// Normalized signal strength 0–100 (maps −90…−30 dBm).
  int? get signalPct {
    final r = _rssiSmooth;
    if (r == null) return null;
    return (((r + 90) / 60) * 100).round().clamp(0, 100);
  }

  /// Human proximity band from smoothed RSSI.
  String? get proximityBand {
    final r = _rssiSmooth;
    if (r == null) return null;
    if (r >= -55) return 'very close';
    if (r >= -70) return 'nearby';
    if (r >= -80) return 'in range';
    return 'weak signal';
  }

  /// Free-space path-loss estimate on the smoothed value.
  double? get proximityM => _rssiSmooth == null
      ? null
      : math.pow(10.0, (-59 - _rssiSmooth!) / 20.0).toDouble();

  /// Attach to a live watch relay. Order matters on Samsung: request the
  /// notification + location permissions *first*, then start the
  /// foreground service — a denied notification permission silently drops
  /// the FGS on API 33+.
  Future<void> attach(WatchRelay relay,
      {bool backgroundRelay = true, bool gpsTrace = true}) async {
    _relay = relay;
    _backgroundOn = backgroundRelay;
    _gpsOn = gpsTrace;
    notifyListeners();

    await _requestPermissions();
    if (_backgroundOn) await _ensureForegroundService();

    _rssiTimer ??=
        Timer.periodic(const Duration(seconds: 2), (_) => _pollRssi());
    unawaited(_pollRssi());
    _startPositionStream();

    // Diagnostics heartbeat — visible in `adb logcat | grep trace` while
    // the screen is off: proves BLE rx, upload, and FGS state.
    _diagTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      final r = _relay;
      debugPrint('[trace] fgs=$_fgsRunning rssi=$_lastRssi '
          'motionRx=${r?.link?.motionRx} '
          'sent=${r?.chunksSent} failed=${r?.chunksFailed} '
          'buf=${r?.bufferedSamples} pts=${trace.length}');
    });
  }

  Future<void> detach() async {
    _relay = null;
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _diagTimer?.cancel();
    _diagTimer = null;
    await _posSub?.cancel();
    _posSub = null;
    _lastFix = null;
    _lastKept = null;
    if (_fgsRunning) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
      _fgsRunning = false;
    }
    notifyListeners();
  }

  /// Live toggle from settings — start/stop the foreground service while
  /// a watch stays connected.
  Future<void> setBackgroundRelay(bool on) async {
    _backgroundOn = on;
    if (on && _relay != null) {
      await _ensureForegroundService();
    } else if (!on && _fgsRunning) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
      _fgsRunning = false;
    }
    notifyListeners();
  }

  Future<void> setGpsTrace(bool on) async {
    _gpsOn = on;
    if (!on) {
      await _posSub?.cancel();
      _posSub = null;
    } else if (_relay != null) {
      _startPositionStream();
    }
    notifyListeners();
  }

  /// Ask once to exempt the app from battery optimization — the single
  /// biggest reason BLE-holding apps get killed on Samsung.
  Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid || _batteryOptAsked) return;
    _batteryOptAsked = true;
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
  }

  void clearTrace() {
    trace.clear();
    _lastKept = null;
    _distanceM = 0;
    notifyListeners();
  }

  Future<void> _pollRssi() async {
    final relay = _relay;
    final link = relay?.link;
    if (link == null) return;
    final rssi = await link.readRssi();
    if (rssi == null || relay == null) return;
    _lastRssi = rssi;
    _rssiSmooth = _rssiSmooth == null
        ? rssi.toDouble()
        : _emaAlpha * rssi + (1 - _emaAlpha) * _rssiSmooth!;
    relay.addLocal(WatchTelemetry(rssi: _rssiSmooth!.round()));
    notifyListeners();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid || _permitted) return;
    _permitted = true;
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('[trace] permission request failed: $e');
    }
  }

  void _startPositionStream() {
    if (_posSub != null || !_gpsOn) return;
    _posSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // meters between candidate fixes
        intervalDuration: const Duration(seconds: 2),
      ),
    ).listen(_onPosition, onError: (Object e) {
      debugPrint('[trace] position error: $e');
      // A one-time deny (or revoked grant) kills the stream — re-ask
      // next attach instead of staying latched denied for the session.
      _permitted = false;
      _posSub?.cancel();
      _posSub = null;
    });
  }

  void _onPosition(Position p) {
    _lastFix = p;
    // Jitter filter: drop poor fixes and points that didn't actually move.
    if (p.accuracy > _dropAccuracyM) return;
    final prev = _lastKept;
    if (prev != null) {
      final d = _haversineM(prev.lat, prev.lon, p.latitude, p.longitude);
      if (d < _minStepM) return;
      _distanceM += d;
    }
    final point = TracePoint(
      at: p.timestamp.toUtc(),
      lat: p.latitude,
      lon: p.longitude,
      accuracyM: p.accuracy,
      speedMps: p.speed >= 0 ? p.speed : null,
      rssi: _rssiSmooth?.round() ?? _lastRssi,
    );
    _lastKept = point;
    trace.add(point);
    if (trace.length > _maxTrace) {
      trace.removeRange(0, trace.length - _maxTrace);
    }
    _traceOut.add(point);

    // Feed the fix into the watch's Brain stream (pinetime-gps).
    _relay?.addLocal(WatchTelemetry(
      lat: p.latitude,
      lon: p.longitude,
      accuracyM: p.accuracy,
      speedMps: p.speed >= 0 ? p.speed : null,
      rssi: _rssiSmooth?.round(),
    ));
    notifyListeners();
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  Future<void> _ensureForegroundService() async {
    if (_fgsRunning || !Platform.isAndroid) return;
    try {
      if (!_fgInited) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'watch_relay',
            channelName: 'PineTime relay',
            channelDescription:
                'Keeps the BLE link and GPS trace alive while the screen is off.',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
          ),
          iosNotificationOptions: const IOSNotificationOptions(),
          // allowWakeLock keeps BLE/GPS timers firing; allowWifiLock stops
          // the WiFi radio sleeping so Brain chunk uploads don't stall
          // behind the screen-off power-save state.
          foregroundTaskOptions: ForegroundTaskOptions(
              eventAction: ForegroundTaskEventAction.nothing(),
              autoRunOnBoot: false,
              allowWakeLock: true,
              allowWifiLock: true),
        );
        _fgInited = true;
      }
      if (await FlutterForegroundTask.isRunningService) {
        _fgsRunning = true;
      } else {
        final res = await FlutterForegroundTask.startService(
          notificationTitle: 'Thothcraft',
          notificationText: 'PineTime relay active — IMU + GPS streaming',
        );
        _fgsRunning = res is ServiceRequestSuccess;
        if (!_fgsRunning) {
          debugPrint('[trace] startService failed: $res');
        }
      }
    } catch (e) {
      debugPrint('[trace] foreground service failed: $e');
      _fgsRunning = false;
    }
    notifyListeners();
  }
}
