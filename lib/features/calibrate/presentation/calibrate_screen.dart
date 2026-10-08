import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../context/application/context_providers.dart';
import '../../context/domain/models.dart';

/// Localization calibration (Part 8): select a space → stand/walk at
/// labeled points → collect BLE fingerprint vectors → save → validate.
/// Only BLE evidence is required; radar/camera appear when the space's
/// nodes provide them — the flow degrades gracefully without a camera.
class CalibrateScreen extends ConsumerStatefulWidget {
  const CalibrateScreen({super.key});

  @override
  ConsumerState<CalibrateScreen> createState() => _CalibrateScreenState();
}

enum _Phase { pickSpace, defineZones, collect, validate }

class _CalibrateScreenState extends ConsumerState<CalibrateScreen> {
  _Phase _phase = _Phase.pickSpace;
  SpaceInfo? _space;
  final _zoneName = TextEditingController();
  final List<String> _zones = [];
  String? _activeZone;
  final Map<String, List<Map<String, num>>> _fingerprints = {};
  Timer? _collectTimer;
  bool _saving = false;

  @override
  void dispose() {
    _collectTimer?.cancel();
    _zoneName.dispose();
    super.dispose();
  }

  /// Sample the current BLE observation map once per second into the
  /// active zone's fingerprint vector. Targets are the enrolled nodes'
  /// BLE identities — collected from live evidence, not a scan of
  /// unknown neighbors.
  void _toggleCollect() {
    if (_collectTimer != null) {
      _collectTimer!.cancel();
      _collectTimer = null;
      setState(() {});
      return;
    }
    _collectTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Read freshest BLE edges as the fingerprint sample.
      final edges =
          ref.read(bleRelationsProvider).valueOrNull ?? const [];
      final vec = <String, num>{};
      for (final e in edges) {
        vec[e.observer] = e.rssiDbm.round();
      }
      if (vec.isEmpty) return;
      _fingerprints.putIfAbsent(_activeZone ?? 'space', () => []).add(vec);
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(contextRepoProvider);
      // Persist calibration as evidence: the estimator consumes
      // fingerprint vectors keyed by zone. It is evidence — the
      // resulting accuracy is what validate reports back.
      final items = <Map<String, dynamic>>[];
      for (final entry in _fingerprints.entries) {
        items.add({
          'key': 'localization.fingerprint.v1',
          'value': {
            'space_id': _space!.id,
            'zone': entry.key,
            'vector': entry.value.length == 1
                ? entry.value.first
                : _average(entry.value),
            'samples': entry.value.length,
          },
          'external_id': const Uuid().v4(),
          'source_id': 'mobile.calibration',
          'provenance': {
            'space': _space!.name,
            'collected_by': 'thoth-app',
          },
        });
      }
      if (items.isNotEmpty) await repo.postEvidence(items);
      setState(() => _phase = _Phase.validate);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, num> _average(List<Map<String, num>> rows) {
    final acc = <String, List<num>>{};
    for (final r in rows) {
      r.forEach((k, v) => acc.putIfAbsent(k, () => []).add(v));
    }
    return acc.map((k, v) =>
        MapEntry(k, v.reduce((a, b) => a + b) / v.length),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibrate space')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _steps(),
        const SizedBox(height: 16),
        switch (_phase) {
          _Phase.pickSpace => _pickSpace(),
          _Phase.defineZones => _defineZones(),
          _Phase.collect => _collect(),
          _Phase.validate => _validate(),
        },
      ],),
    );
  }

  Widget _steps() {
    const labels = ['Space', 'Zones', 'Collect', 'Validate'];
    final idx = _phase.index;
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0)
          const Expanded(child: Divider(indent: 4, endIndent: 4)),
        Column(children: [
          Icon(
              i < idx
                  ? Icons.check_circle
                  : i == idx
                      ? Icons.radio_button_checked
                      : Icons.circle_outlined,
              size: 18,
              color: i <= idx
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,),
          Text(labels[i], style: const TextStyle(fontSize: 10)),
        ],),
      ],
    ],);
  }

  Widget _pickSpace() {
    final spaces = ref.watch(spacesLiveProvider);
    return spaces.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (list) => Column(children: [
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Which space are you calibrating?'),),
        const SizedBox(height: 12),
        for (final s in list)
          Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Text(
                  '${s.placements.length} node(s) placed'
                  '${s.zones.isNotEmpty ? ' · ${s.zones.length} zones' : ''}'),
              onTap: () => setState(() {
                _space = s;
                _zones.addAll(s.zones
                    .map((z) => '${z['name']}')
                    .where((n) => n.isNotEmpty),);
                _phase =
                    _zones.isEmpty ? _Phase.defineZones : _Phase.collect;
                _activeZone = _zones.isNotEmpty ? _zones.first : 'space';
              }),
            ),
          ),
      ],),
    );
  }

  Widget _defineZones() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Optional — name the spots you\'ll walk to '
          '(e.g. desk, sofa, door).'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _zoneName,
                decoration:
                    const InputDecoration(hintText: 'zone name'),),),
        IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              if (_zoneName.text.trim().isNotEmpty) {
                setState(() {
                  _zones.add(_zoneName.text.trim());
                  _zoneName.clear();
                });
              }
            },),
      ],),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final z in _zones) Chip(label: Text(z)),
        if (_zones.isEmpty)
          const Chip(label: Text('whole space')),
      ],),
      const SizedBox(height: 20),
      FilledButton(
          onPressed: () => setState(() {
                _phase = _Phase.collect;
                _activeZone = _zones.isNotEmpty ? _zones.first : 'space';
              }),
          child: const Text('Start collecting'),),
    ],);
  }

  Widget _collect() {
    final spots = _zones.isEmpty ? const ['space'] : _zones;
    final collecting = _collectTimer != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Stand at each spot and collect a fingerprint. '
          'Radar/camera data (when the node has them) is fused by the '
          'estimator — you only walk with your wearable or phone.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black54),),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: [
          for (final z in spots)
            ButtonSegment(value: z, label: Text(z)),
        ],
        selected: {_activeZone ?? spots.first},
        onSelectionChanged: (s) =>
            setState(() => _activeZone = s.first),
      ),
      const SizedBox(height: 16),
      Center(
        child: Column(children: [
          Text(
              '${_fingerprints[_activeZone ?? spots.first]?.length ?? 0} samples',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700,),),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: Icon(collecting ? Icons.stop : Icons.play_arrow),
            label: Text(collecting ? 'Stop' : 'Collect here'),
            onPressed: _toggleCollect,
          ),
        ],),
      ),
      const SizedBox(height: 20),
      FilledButton.tonal(
          onPressed: _fingerprints.isEmpty || _saving
              ? null
              : () => unawaited(_save()),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),)
              : const Text('Save calibration'),),
    ],);
  }

  Widget _validate() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Validation',
          style: TextStyle(fontWeight: FontWeight.w600),),
      const SizedBox(height: 8),
      const Text(
          'Walk between zones — the estimator compares live BLE evidence '
          'to the saved fingerprints and reports accuracy back through '
          'context state (location.zone.v1).',
          style: TextStyle(color: Colors.black54, fontSize: 12),),
      const SizedBox(height: 12),
      // Live zone estimate, if the estimator is already producing it.
      Consumer(builder: (context, ref, _) {
        final snap = ref.watch(contextSnapshotProvider);
        final zoneStates = snap.valueOrNull?.states
                .where((s) => s.key == ContextKeys.locationZone && s.active)
                .toList() ??
            const <ContextState>[];
        if (zoneStates.isEmpty) {
          return const Text(
              'No zone estimate yet — the estimator will publish '
              'location.zone.v1 once it has enough evidence.',
              style: TextStyle(fontSize: 12),);
        }
        return Column(children: [
          for (final s in zoneStates)
            ListTile(
              dense: true,
              leading: const Icon(Icons.my_location, size: 18),
              title: Text('${s.entityId} → ${s.value}'),
              subtitle: Text('${(s.confidence * 100).round()}% · '
                  '${s.estimator}'),
            ),
        ],);
      },),
      const SizedBox(height: 20),
      FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),),
    ],);
  }
}
