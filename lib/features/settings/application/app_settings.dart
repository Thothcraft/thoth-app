import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing app settings persisted via SharedPreferences.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,

    /// Foreground service + wakelock so the watch BLE link keeps streaming
    /// IMU/RSSI while the phone screen is off. Costs some battery.
    this.backgroundRelay = true,

    /// Collect phone GPS fixes into the movement trace while a watch is
    /// connected (powers the Trace tab + the pinetime-gps Brain stream).
    this.gpsTrace = true,

    /// Whether we've already shown the battery-optimization prompt once —
    /// Samsung aggressively kills BLE-holding apps without the exemption.
    this.batteryOptPrompted = false,

    // ── Privacy/source toggles (Part 11) — each gates a distinct
    // evidence producer; all default OFF so nothing is collected until
    // the user opts in.

    /// BLE scan duty-cycling that posts RSSI evidence for enrolled
    /// devices only (never fingerprints unknown neighbors).
    this.bleRssiCollection = false,

    /// Post phone GPS fixes as geographic/site evidence — distinct from
    /// BLE room association. Requires foreground location permission.
    this.gpsEvidence = false,

    /// Optional phone accelerometer → coarse motion evidence.
    this.phoneMotion = false,

    /// Cached account username for source labels.
    this.username,
  });

  final ThemeMode themeMode;
  final bool backgroundRelay;
  final bool gpsTrace;
  final bool batteryOptPrompted;
  final bool bleRssiCollection;
  final bool gpsEvidence;
  final bool phoneMotion;
  final String? username;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? backgroundRelay,
    bool? gpsTrace,
    bool? batteryOptPrompted,
    bool? bleRssiCollection,
    bool? gpsEvidence,
    bool? phoneMotion,
    String? username,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        backgroundRelay: backgroundRelay ?? this.backgroundRelay,
        gpsTrace: gpsTrace ?? this.gpsTrace,
        batteryOptPrompted: batteryOptPrompted ?? this.batteryOptPrompted,
        bleRssiCollection: bleRssiCollection ?? this.bleRssiCollection,
        gpsEvidence: gpsEvidence ?? this.gpsEvidence,
        phoneMotion: phoneMotion ?? this.phoneMotion,
        username: username ?? this.username,
      );

  static const _kTheme = 'settings.theme';
  static const _kBgRelay = 'settings.bg_relay';
  static const _kGps = 'settings.gps_trace';
  static const _kBattOpt = 'settings.battery_opt_prompted';
  static const _kBleRssi = 'settings.ble_rssi';
  static const _kGpsEvidence = 'settings.gps_evidence';
  static const _kMotion = 'settings.phone_motion';
  static const _kUsername = 'settings.username';
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
        AppSettingsNotifier.new);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: switch (p.getString(AppSettings._kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      backgroundRelay: p.getBool(AppSettings._kBgRelay) ?? true,
      gpsTrace: p.getBool(AppSettings._kGps) ?? true,
      batteryOptPrompted: p.getBool(AppSettings._kBattOpt) ?? false,
      bleRssiCollection: p.getBool(AppSettings._kBleRssi) ?? false,
      gpsEvidence: p.getBool(AppSettings._kGpsEvidence) ?? false,
      phoneMotion: p.getBool(AppSettings._kMotion) ?? false,
      username: p.getString(AppSettings._kUsername),
    );
  }

  Future<void> _save(void Function(SharedPreferences) fn) async {
    final p = await SharedPreferences.getInstance();
    fn(p);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = AsyncData(state.valueOrNull?.copyWith(themeMode: m) ??
        AppSettings(themeMode: m));
    await _save((p) => p.setString(AppSettings._kTheme, m.name));
  }

  Future<void> setBackgroundRelay(bool v) async {
    state =
        AsyncData((state.valueOrNull ?? const AppSettings()).copyWith(backgroundRelay: v));
    await _save((p) => p.setBool(AppSettings._kBgRelay, v));
  }

  Future<void> setGpsTrace(bool v) async {
    state =
        AsyncData((state.valueOrNull ?? const AppSettings()).copyWith(gpsTrace: v));
    await _save((p) => p.setBool(AppSettings._kGps, v));
  }

  Future<void> setBatteryOptPrompted() async {
    state = AsyncData(
        (state.valueOrNull ?? const AppSettings()).copyWith(batteryOptPrompted: true));
    await _save((p) => p.setBool(AppSettings._kBattOpt, true));
  }

  // ── privacy/source toggles ───────────────────────────────────────────────

  Future<void> setBleRssiCollection(bool v) async {
    state = AsyncData((state.valueOrNull ?? const AppSettings())
        .copyWith(bleRssiCollection: v));
    await _save((p) => p.setBool(AppSettings._kBleRssi, v));
  }

  Future<void> setGpsEvidence(bool v) async {
    state = AsyncData((state.valueOrNull ?? const AppSettings())
        .copyWith(gpsEvidence: v));
    await _save((p) => p.setBool(AppSettings._kGpsEvidence, v));
  }

  Future<void> setPhoneMotion(bool v) async {
    state = AsyncData((state.valueOrNull ?? const AppSettings())
        .copyWith(phoneMotion: v));
    await _save((p) => p.setBool(AppSettings._kMotion, v));
  }

  Future<void> setUsername(String? v) async {
    state = AsyncData((state.valueOrNull ?? const AppSettings())
        .copyWith(username: v));
    await _save((p) => v == null
        ? p.remove(AppSettings._kUsername)
        : p.setString(AppSettings._kUsername, v));
  }
}
