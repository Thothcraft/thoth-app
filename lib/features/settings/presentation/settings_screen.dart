import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../watch/data/trace_service.dart';
import '../application/app_settings.dart';

/// Settings — app preferences + watch relay controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider).valueOrNull;
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            subtitle: Text(switch (s?.themeMode) {
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
              _ => 'System',
            }),
            onTap: () => _pickTheme(context, notifier, s?.themeMode),
          ),
          const Divider(height: 24),
          const _SectionLabel('PineTime relay'),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait),
            title: const Text('Background streaming'),
            subtitle: const Text(
                'Keep IMU + proximity data flowing with the screen off'),
            value: s?.backgroundRelay ?? true,
            onChanged: notifier.setBackgroundRelay,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.route),
            title: const Text('GPS trace'),
            subtitle: const Text(
                'Record phone location + watch signal for the Trace map'),
            value: s?.gpsTrace ?? true,
            onChanged: notifier.setGpsTrace,
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Disable battery optimization'),
            subtitle: const Text(
                'Recommended on Samsung — prevents Android killing the relay'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                TraceService.instance.requestBatteryOptimizationExemption(),
          ),
          const Divider(height: 24),
          const _SectionLabel('Sources & privacy'),
          // Part 11 — every collection source has an explicit toggle and
          // plain-language description of what leaves the phone.
          SwitchListTile(
            secondary: const Icon(Icons.bluetooth_searching),
            title: const Text('BLE proximity evidence'),
            subtitle: const Text(
                'Post RSSI for enrolled devices plus unenrolled '
                'advertisers (shown as unknowns on the BLE map). Ids '
                'stay on your account only.'),
            value: s?.bleRssiCollection ?? false,
            onChanged: notifier.setBleRssiCollection,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('GPS site evidence'),
            subtitle: const Text(
                'Share phone GPS as geographic evidence — separate from '
                'in-room BLE localization. Location permission required.'),
            value: s?.gpsEvidence ?? false,
            onChanged: notifier.setGpsEvidence,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Phone motion'),
            subtitle: const Text(
                'Optional accelerometer evidence — coarse activity only'),
            value: s?.phoneMotion ?? false,
            onChanged: notifier.setPhoneMotion,
          ),
          const ListTile(
            dense: true,
            leading: Icon(Icons.shield_outlined, size: 18),
            title: Text(
                'Evidence = raw observations attributed to your account. '
                'Context states (who is where) are derived by estimators '
                'and show their confidence — evidence is never presented '
                'as asserted truth.',
                style: TextStyle(fontSize: 11, color: Colors.black45)),
          ),
          const Divider(height: 24),
          const _SectionLabel('Location zones'),
          ListTile(
            dense: true,
            leading: const Icon(Icons.map_outlined, size: 18),
            title: const Text(
                'Map-level geofences for the person entity — entering a '
                'zone posts a transition and sets your location.zone '
                'state. Requires GPS evidence on.',
                style: TextStyle(fontSize: 11, color: Colors.black45)),
          ),
          for (final z in s?.geoZones ?? const <GeoZone>[])
            ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined),
              title: Text(z.name),
              subtitle: Text(
                  '${z.latitude.toStringAsFixed(5)}, '
                  '${z.longitude.toStringAsFixed(5)} · '
                  '${z.radiusM.toStringAsFixed(0)} m',
                  style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => notifier.setGeoZones([
                  for (final x in s!.geoZones)
                    if (x.name != z.name) x,
                ]),
              ),
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('Add zone at current location'),
            onTap: () => _addZoneHere(context, ref),
          ),
          const Divider(height: 24),
          const _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Thothcraft'),
            subtitle: const Text('${AppConstants.appName} · version 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Research portal'),
            subtitle: const Text('Open the web dashboard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/research'),
          ),
        ],
      ),
    );
  }

  /// Name + radius dialog → adds a geofence at the phone's live fix.
  Future<void> _addZoneHere(BuildContext context, WidgetRef ref) async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission needed to place a zone')));
      }
      return;
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No GPS fix: $e')));
      }
      return;
    }
    if (!context.mounted) return;

    final nameCtrl = TextEditingController();
    var radius = 150.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => AlertDialog(
          title: const Text('New zone'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'home / office / backyard / university',
                  labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Radius'),
              Expanded(
                child: Slider(
                  value: radius,
                  min: 25,
                  max: 1000,
                  divisions: 39,
                  label: '${radius.round()} m',
                  onChanged: (v) => setD(() => radius = v),
                ),
              ),
              Text('${radius.round()} m',
                  style: const TextStyle(fontSize: 11)),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final s = ref.read(appSettingsProvider).valueOrNull ??
        const AppSettings();
    await ref.read(appSettingsProvider.notifier).setGeoZones([
      ...s.geoZones,
      GeoZone(
          name: nameCtrl.text.trim().toLowerCase(),
          latitude: pos.latitude,
          longitude: pos.longitude,
          radiusM: radius),
    ]);
  }

  void _pickTheme(BuildContext context, AppSettingsNotifier notifier,
      ThemeMode? current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, mode, icon) in [
              ('System', ThemeMode.system, Icons.settings_suggest),
              ('Light', ThemeMode.light, Icons.light_mode_outlined),
              ('Dark', ThemeMode.dark, Icons.dark_mode_outlined),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: current == mode
                    ? Icon(Icons.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  notifier.setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
