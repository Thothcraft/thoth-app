import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/api/node_client.dart';
import '../../devices/application/devices_provider.dart';
import '../../devices/presentation/room_settings_screen.dart';
import '../application/context_providers.dart';

/// Configured 3D geometry and live radio links share one coordinate frame.
/// Unlocated endpoints never inherit a peer's position or floor.
class SpatialMapView extends StatefulWidget {
  const SpatialMapView({super.key, required this.devices, required this.edges});
  final List<ThothDevice> devices;
  final List<BleRelation> edges;
  @override
  State<SpatialMapView> createState() => _SpatialMapViewState();
}

class _SpatialMapViewState extends State<SpatialMapView> {
  Map<String, Map<String, dynamic>> _docs = {};
  List<String> _unavailable = [];
  bool _loading = false;
  bool _top = false;
  String? _building;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SpatialMapView old) {
    super.didUpdateWidget(old);
    if (old.devices.map((d) => d.uuid).join() !=
        widget.devices.map((d) => d.uuid).join()) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = <String, Map<String, dynamic>>{}, failed = <String>[];
    await Future.wait(widget.devices.map((device) async {
      try {
        final cached = await NodeClient.instance.room(device.uuid);
        final room = cached['room'];
        if (room is Map)
          docs[device.uuid] = Map<String, dynamic>.from(room);
        else
          failed.add(device.name);
      } catch (_) {
        failed.add(device.name);
      }
    }));
    if (mounted)
      setState(() {
        _docs = docs;
        _unavailable = failed;
        _loading = false;
      });
  }

  Future<void> _configure(ThothDevice d) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RoomSettingsScreen(deviceId: d.uuid)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scene = SpatialScene.fromDocuments(_docs);
    final buildings = scene.rooms.map((r) => r.building).toSet().toList()
      ..sort();
    final selected =
        buildings.contains(_building) ? _building : buildings.firstOrNull;
    final rooms = scene.rooms.where((r) => r.building == selected).toList();
    final points = scene.points.where((p) => p.building == selected).toList();
    final placed = scene.points.map((p) => p.id).toSet();
    final unlocated = <String>{
      for (final d in widget.devices) d.uuid,
      for (final e in widget.edges) ...[e.observer, e.target]
    }.difference(placed).length;
    return Column(children: [
      Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (buildings.length > 1)
              DropdownButton<String>(
                  value: selected,
                  items: buildings
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (b) => setState(() => _building = b)),
            TextButton.icon(
                onPressed: () => setState(() => _top = !_top),
                icon: Icon(_top ? Icons.view_in_ar : Icons.map_outlined),
                label: Text(_top ? '3D view' : 'Top view')),
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh room layouts'),
            PopupMenuButton<ThothDevice>(
                tooltip: 'Configure house and rooms',
                icon: const Icon(Icons.home_work_outlined),
                itemBuilder: (_) => widget.devices
                    .map((d) => PopupMenuItem(
                        value: d, child: Text('Configure ${d.name}')))
                    .toList(),
                onSelected: _configure),
          ]),
      if (_loading) const LinearProgressIndicator(),
      if (_unavailable.isNotEmpty)
        Text('Layout unavailable: ${_unavailable.join(', ')}',
            style: const TextStyle(fontSize: 11)),
      if (scene.conflicts.isNotEmpty)
        Text('Conflicting placements: ${scene.conflicts.join(', ')}',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.home_work_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text('Set up your house and room anchors',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text(
                            'Choose a device above to enter the house location, measured room layout, floor, direction and device position. Unconfigured radio devices remain unlocated.',
                            textAlign: TextAlign.center),
                      ])))
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 8,
                  child: LayoutBuilder(
                      builder: (_, constraints) => CustomPaint(
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight),
                            painter: _SpatialPainter(
                                rooms, points, widget.edges, _top),
                          )))),
      Text('${points.length} declared anchors · $unlocated unlocated devices',
          style: const TextStyle(fontSize: 12)),
      for (final p in points.take(6))
        Text(
            '${p.id} · floor ${p.floor ?? 'unknown'} · height ${p.enu[2].toStringAsFixed(1)} m · ${p.membership}',
            style: const TextStyle(fontSize: 11)),
      const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
              'Positions are configured anchors. Live radio links do not yet provide calibrated device coordinates.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11))),
    ]);
  }
}

bool _finite(dynamic v) => v is num && v.isFinite;
List<double>? _v3(dynamic v) => v is List && v.length == 3 && v.every(_finite)
    ? v.map((e) => (e as num).toDouble()).toList()
    : null;
List<double> roomToEnu(List<double> p, List<double> origin, double heading) {
  final a = heading * math.pi / 180;
  return [
    origin[0] + p[0] * math.cos(a) - p[2] * math.sin(a),
    origin[1] - p[0] * math.sin(a) - p[2] * math.cos(a),
    origin[2] + p[1]
  ];
}

class SpatialRoom {
  SpatialRoom(this.building, this.id, this.name, this.corners);
  final String building, id, name;
  final List<List<double>> corners;
}

class SpatialPoint {
  SpatialPoint(this.id, this.building, this.enu, this.floor, this.membership);
  final String id, building, membership;
  final List<double> enu;
  final int? floor;
}

class SpatialScene {
  final rooms = <SpatialRoom>[];
  final points = <SpatialPoint>[];
  final conflicts = <String>{};
  SpatialScene.fromDocuments(Map<String, Map<String, dynamic>> docs) {
    final uniqueRooms = <String, SpatialRoom>{},
        uniquePoints = <String, SpatialPoint>{};
    for (final doc in docs.values) {
      final building = '${(doc['building'] as Map?)?['id'] ?? ''}';
      if (building.isEmpty) continue;
      for (final r in [
        doc,
        ...(doc['rooms'] as List? ?? []).whereType<Map>()
      ]) {
        final id = '${r['room_id'] ?? ''}',
            s = r['spatial'] as Map? ?? {},
            dims = r['dims'] as Map? ?? {};
        final origin = _v3(s['origin_enu_m']);
        if (s['surveyed'] != true ||
            origin == null ||
            !_finite(s['heading_deg']) ||
            ![
              'w',
              'd',
              'h'
            ].every((k) => _finite(dims[k]) && (dims[k] as num) > 0)) continue;
        final heading = (s['heading_deg'] as num).toDouble(),
            w = (dims['w'] as num).toDouble(),
            d = (dims['d'] as num).toDouble(),
            h = (dims['h'] as num).toDouble();
        final corners = [
          for (final y in [0.0, h])
            for (final p in [
              [-w / 2, y, -d / 2],
              [w / 2, y, -d / 2],
              [w / 2, y, d / 2],
              [-w / 2, y, d / 2]
            ])
              roomToEnu(p, origin, heading)
        ];
        uniqueRooms['$building/$id'] =
            SpatialRoom(building, id, '${r['name'] ?? id}', corners);
        for (final dev in (doc['devices'] as List? ?? []).whereType<Map>()) {
          final roomId =
              '${dev['room_id'] == '' || dev['room_id'] == null ? doc['room_id'] ?? '' : dev['room_id']}';
          final p = _v3(dev['pos']);
          if (roomId != id || p == null) continue;
          final did = '${dev['device_id'] ?? ''}';
          if (did.isEmpty) continue;
          final enu = roomToEnu(p, origin, heading),
              uncertainty = dev['position_uncertainty_m'];
          final margin = [
            w / 2 - p[0].abs(),
            d / 2 - p[2].abs(),
            p[1],
            h - p[1]
          ].reduce(math.min);
          final membership = !_finite(uncertainty) || uncertainty < 0
              ? 'inside/outside unknown'
              : margin > uncertainty
                  ? 'inside room'
                  : margin < -uncertainty
                      ? 'outside room'
                      : 'near room boundary';
          final point = SpatialPoint(did, building, enu,
              s['floor'] is int ? s['floor'] : null, membership);
          final old = uniquePoints[did];
          if (old != null &&
              (old.building != building ||
                  List.generate(3, (i) => (old.enu[i] - enu[i]).abs() > 0.001)
                      .any((v) => v))) conflicts.add(did);
          uniquePoints[did] = point;
        }
      }
    }
    rooms.addAll(uniqueRooms.values);
    points.addAll(uniquePoints.values.where((p) => !conflicts.contains(p.id)));
  }
}

class _SpatialPainter extends CustomPainter {
  _SpatialPainter(this.rooms, this.points, this.edges, this.top);
  final List<SpatialRoom> rooms;
  final List<SpatialPoint> points;
  final List<BleRelation> edges;
  final bool top;
  @override
  void paint(Canvas canvas, Size size) {
    Offset project(List<double> p) => top
        ? Offset(p[0], -p[1])
        : Offset((p[0] - p[1]) * 0.75, (p[0] + p[1]) * 0.35 - p[2]);
    final all = [
      for (final r in rooms) ...r.corners,
      for (final p in points) p.enu
    ].map(project).toList();
    if (all.isEmpty) return;
    final minX = all.map((p) => p.dx).reduce(math.min),
        maxX = all.map((p) => p.dx).reduce(math.max),
        minY = all.map((p) => p.dy).reduce(math.min),
        maxY = all.map((p) => p.dy).reduce(math.max);
    final scale = math.max(
        1.0,
        math.min((size.width - 80) / math.max(1, maxX - minX),
            (size.height - 80) / math.max(1, maxY - minY)));
    Offset at(List<double> p) {
      final q = project(p);
      return Offset(40 + (q.dx - minX) * scale, 40 + (q.dy - minY) * scale);
    }

    void text(String s, Offset at, Color color) {
      final t = TextPainter(
          text: TextSpan(text: s, style: TextStyle(fontSize: 11, color: color)),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: 230);
      t.paint(canvas, at);
    }

    final pen = Paint()
      ..color = Colors.blueGrey
      ..strokeWidth = 1.2;
    for (final r in rooms) {
      for (var layer = 0; layer < 2; layer++) {
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(at(r.corners[layer * 4 + i]),
              at(r.corners[layer * 4 + (i + 1) % 4]), pen);
        }
      }
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(at(r.corners[i]), at(r.corners[i + 4]), pen);
      }
      text(r.name, at(r.corners[4]), Colors.blueGrey);
    }
    final byId = {for (final p in points) p.id: p};
    for (final e in edges) {
      final a = byId[e.observer], b = byId[e.target];
      if (a == null || b == null) continue;
      canvas.drawLine(
          at(a.enu),
          at(b.enu),
          Paint()
            ..color = (e.modality == 'CSI' ? Colors.purple : Colors.teal)
                .withValues(alpha: 0.5)
            ..strokeWidth = 2);
    }
    for (final p in points) {
      final q = at(p.enu);
      canvas.drawCircle(q, 5, Paint()..color = Colors.teal);
      text(p.id.length > 12 ? p.id.substring(0, 12) : p.id,
          q + const Offset(7, -5), Colors.teal);
    }
    text(top ? 'North ↑ · East →' : 'East / North / Up · metres',
        const Offset(8, 8), Colors.blueGrey);
  }

  @override
  bool shouldRepaint(covariant _SpatialPainter old) => true;
}
