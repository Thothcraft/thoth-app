import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../context/application/context_providers.dart';
import '../../context/domain/models.dart';
import '../../devices/application/devices_provider.dart';

/// Unified BLE relation map.
///
/// One canvas for the whole radio neighborhood:
///  - Anchored nodes: devices placed in a space render at their plan
///    coordinates (x, y in meters). Space boxes stack by `parent_id`
///    depth — deeper children are "floors above".
///  - Free nodes: BLE peers without a placement orbit their strongest
///    anchor at a radius implied by RSSI (log-distance hint — a signal
///    strength visualization, not a measurement).
///  - Edges: every `ble.proximity.v1` relation between devices, width =
///    RSSI strength, alpha = freshness, dashes = stale.
///
/// Every node carries a 3D descriptor: device type, floor tag,
/// left/right ordering inside its space, and moving/stationary inferred
/// from RSSI variance and activity context.
class BleMapView extends StatefulWidget {
  const BleMapView({
    super.key,
    required this.edges,
    required this.devices,
    required this.spaces,
    this.watchNames = const {},
  });

  final List<BleRelation> edges;
  final List<ThothDevice> devices;
  final List<SpaceInfo> spaces;

  /// bleId (MAC) → friendly name for wearable targets.
  final Map<String, String> watchNames;

  @override
  State<BleMapView> createState() => _BleMapViewState();
}

class _BleMapViewState extends State<BleMapView> {
  String? _selected;

  /// User-renamed node labels — persisted locally; keyed by node id
  /// (device uuid, ``ble:<MAC>``, entity id…).
  Map<String, String> _overrides = const {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final raw = p.getString('ble_map_labels');
      if (raw != null && mounted) {
        setState(() => _overrides =
            Map<String, String>.from(jsonDecode(raw) as Map));
      }
    });
  }

  Future<void> _rename(_Node n) async {
    final ctrl = TextEditingController(
        text: _overrides[n.id] ?? n.label);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Label for ${n.id.length > 24
            ? '${n.id.substring(0, 24)}…'
            : n.id}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'e.g. hallway beacon'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, ''),
              child: const Text('Reset')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || !mounted) return;
    setState(() {
      _overrides = {..._overrides}..remove(n.id);
      if (name.isNotEmpty) _overrides[n.id] = name;
    });
    final p = await SharedPreferences.getInstance();
    await p.setString('ble_map_labels', jsonEncode(_overrides));
  }

  /// Invert the painter transform, hit-test node centers in canvas px.
  void _onTap(Offset local, Size size, _Scene scene) {
    final world = scene.worldRect();
    final scale = math.min(size.width / (world.width + 0.8),
        size.height / (world.height + 0.8));
    Offset map(Offset w) => Offset(
        (w.dx - world.left - 0.4) * scale +
            (size.width - (world.width + 0.8) * scale) / 2,
        (w.dy - world.top - 0.4) * scale +
            (size.height - (world.height + 0.8) * scale) / 2);
    String? hit;
    var best = 28.0; // tap radius in px
    for (final n in scene.nodes.values) {
      final d = (map(n.pos) - local).distance;
      if (d < best) {
        best = d;
        hit = n.id;
      }
    }
    setState(() => _selected = hit == _selected ? null : hit);
  }

  @override
  Widget build(BuildContext context) {
    final scene = _Scene.build(
        edges: widget.edges,
        devices: widget.devices,
        spaces: widget.spaces,
        watchNames: widget.watchNames,
        labelOverrides: _overrides);
    final sel = _selected != null ? scene.nodes[_selected] : null;
    final selEdges = sel == null
        ? const <BleRelation>[]
        : (widget.edges
                .where((e) => e.observer == sel.id || e.target == sel.id)
                .toList()
              ..sort((a, b) => b.rssiDbm.compareTo(a.rssiDbm)));

    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTap(d.localPosition, size, scene),
            child: CustomPaint(
              painter: _BleMapPainter(scene, selectedId: _selected),
              child: const SizedBox.expand(),
            ),
          );
        }),
      ),
      // Selection strip — the tapped node's links to everything else.
      if (sel != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.blueGrey.withValues(alpha: 0.08),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                child: Text(
                  '${sel.label}${sel.known ? '' : '  (unknown)'}'
                  '${sel.floor.isEmpty ? '' : ' · ${sel.floor}'}'
                  '${sel.estimated ? ' · ~est' : ''}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: () => _rename(sel),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 14,
                      color: Colors.black45),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            if (selEdges.isEmpty)
              const Text('no live links',
                  style: TextStyle(fontSize: 11, color: Colors.black54))
            else
              for (final e in selEdges.take(6))
                Text(
                  '${_peerName(sel.id, e, scene)}  ${e.rssiDbm.round()} dBm'
                  '${e.count > 1 ? ' ×${e.count}' : ''}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54),
                ),
          ]),
        ),
    ]);
  }

  String _peerName(String selId, BleRelation e, _Scene scene) {
    final other = e.observer == selId ? e.target : e.observer;
    final n = scene.nodes[other];
    return '${e.observer == selId ? '→' : '←'} ${n?.label ?? other}';
  }
}

// ── scene model ─────────────────────────────────────────────────────────────

class _Node {
  _Node({
    required this.id,
    required this.label,
    required this.kind,
    this.pos = Offset.zero,
    this.floor = '',
    this.placed = false,
  });

  final String id;
  String label; // user-overridable via the selection strip
  final String kind; // phone | watch | thoth | tv | speaker | unknown
  Offset pos;
  String floor;
  bool moving = false;
  bool placed;
  /// Position solved from ≥2 RSSI anchors (multilateration) — drawn
  /// with an uncertainty ring, not as ground truth.
  bool estimated = false;
  String side = ''; // left | center | right within its space row
  /// False for unenrolled advertisers — drawn as hollow unknowns.
  bool known = true;
  String? advName;
}

class _SpaceBox {
  _SpaceBox({required this.name, required this.depth, required this.rect});
  final String name;
  final int depth; // parent-chain depth → floor above/below
  final Rect rect;
}

class _Scene {
  _Scene(this.nodes, this.edges, this.spaceBoxes);
  final Map<String, _Node> nodes;
  final List<BleRelation> edges;
  final List<_SpaceBox> spaceBoxes;

  /// World-space bounds of everything drawn — shared by the painter
  /// and the tap hit-test so both agree on the transform.
  Rect worldRect() {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    void grow(Offset p) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }

    for (final n in nodes.values) {
      grow(n.pos);
    }
    for (final s in spaceBoxes) {
      grow(s.rect.topLeft);
      grow(s.rect.bottomRight);
    }
    if (!l.isFinite) return const Rect.fromLTWH(0, 0, 3, 2);
    return Rect.fromLTRB(l, t, r, b);
  }

  static String _kind(String? deviceType, String rawId) {
    if (rawId.startsWith('phone:')) return 'phone';
    final t = (deviceType ?? '').toLowerCase();
    if (rawId.contains(':')) {
      // MAC-ish ble ids are wearables in this system.
      if (RegExp(r'^([0-9A-Fa-f]{2}:){5}').hasMatch(rawId)) return 'watch';
    }
    if (t.contains('watch') || t.contains('wearable')) return 'watch';
    if (t.contains('tv') || t.contains('television')) return 'tv';
    if (t.contains('phone')) return 'phone';
    if (t.contains('speaker') || t.contains('audio')) return 'speaker';
    if (t.contains('thoth') || t.isEmpty) return 'thoth';
    return t;
  }

  static double _rssiRadiusM(double rssi) =>
      math.pow(10, (-59 - rssi) / 20).clamp(0.4, 12.0).toDouble();

  static _Scene build({
    required List<BleRelation> edges,
    required List<ThothDevice> devices,
    required List<SpaceInfo> spaces,
    required Map<String, String> watchNames,
    Map<String, String> labelOverrides = const {},
  }) {
    final nodes = <String, _Node>{};
    final byUuid = {for (final d in devices) d.uuid: d};

    // ── 1. Place every anchored device inside its space rect.
    // Space rects are laid out side-by-side, deepest-first is irrelevant
    // here — depth only drives the floor tag.
    final spaceBoxes = <_SpaceBox>[];
    final byId = {for (final s in spaces) s.id: s};
    int depthOf(SpaceInfo s) {
      var d = 0;
      var cur = s;
      final seen = <int>{};
      while (cur.parentId != null &&
          byId.containsKey(cur.parentId) &&
          seen.add(cur.id)) {
        d++;
        cur = byId[cur.parentId]!;
      }
      return d;
    }

    // Layout: root spaces first, then children under their parent. Each
    // box is normalized to a fixed height proportion in painter coords.
    final ordered = [...spaces]
      ..sort((a, b) => depthOf(a).compareTo(depthOf(b)));
    final plan = <int, Rect>{};
    const spaceW = 3.0, spaceH = 2.0; // normalized world units (m-ish)
    const gapX = 0.6, gapY = 0.5;
    var cursor = const Offset(0, 0);
    var rowMaxDepth = -1;
    for (final s in ordered) {
      final depth = depthOf(s);
      if (depth != rowMaxDepth) {
        if (rowMaxDepth >= 0) {
          cursor = Offset(0, cursor.dy + spaceH + gapY);
        }
        rowMaxDepth = depth;
      }
      plan[s.id] = Rect.fromLTWH(cursor.dx, cursor.dy, spaceW, spaceH);
      spaceBoxes.add(_SpaceBox(
          name: s.name, depth: depth, rect: plan[s.id]!));
      cursor = Offset(cursor.dx + spaceW + gapX, cursor.dy);
    }

    void placeIn(int spaceId, String uuid, double x, double y,
        String name, String kind) {
      final r = plan[spaceId];
      if (r == null) return;
      final space = byId[spaceId];
      final w = (space?.widthM ?? 0) > 0 ? space!.widthM! : spaceW;
      final h = (space?.heightM ?? 0) > 0 ? space!.heightM! : spaceH;
      final nx = (x / w).clamp(0.05, 0.95);
      final ny = (y / h).clamp(0.05, 0.95);
      nodes[uuid] = _Node(
        id: uuid,
        label: name,
        kind: kind,
        pos: Offset(r.left + nx * r.width, r.top + ny * r.height),
        floor: _floorTag(space, byId),
        placed: true,
      );
    }

    for (final s in spaces) {
      for (final p in s.placements) {
        final uuid = '${p['device_id'] ?? ''}';
        if (uuid.isEmpty) continue;
        final x = (p['x'] as num?)?.toDouble() ?? 0;
        final y = (p['y'] as num?)?.toDouble() ?? 0;
        final d = byUuid[uuid];
        placeIn(s.id, uuid, x, y,
            '${p['device_name'] ?? d?.name ?? 'device'}',
            _kind(d?.deviceType, uuid));
      }
    }

    // ── 2a. Every account device gets a node — the map is the whole
    // fleet, not only devices that happen to have placements/edges.
    for (final d in devices) {
      if (d.uuid.isEmpty || nodes.containsKey(d.uuid)) continue;
      nodes[d.uuid] = _Node(
        id: d.uuid,
        label: d.name,
        kind: _kind(d.deviceType, d.uuid),
      );
    }

    // ── 2. Nodes appearing only in BLE edges — orbit their strongest
    // anchor. Anchored devices without placement join the free pool.
    for (final e in edges) {
      for (final raw in [e.observer, e.target]) {
        final k = raw;
        if (nodes.containsKey(k)) continue;
        final d = byUuid[k];
        // ble:<MAC> keys normalize lookups back to the raw id.
        final rawId = raw.startsWith('ble:') ? raw.substring(4) : raw;
        final isWatch = watchNames.containsKey(rawId) ||
            RegExp(r'^([0-9A-Fa-f]{2}:){5}').hasMatch(rawId);
        nodes[k] = _Node(
          id: k,
          label: d?.name ??
              watchNames[rawId] ??
              e.advName ??
              raw.split(':').last,
          kind: isWatch ? 'watch' : _kind(d?.deviceType, k),
        );
      }
      // Any endpoint of a discovery edge is an unknown device.
      if (!e.known) {
        for (final raw in [e.observer, e.target]) {
          final n = nodes[raw];
          if (n != null) {
            n.known = false;
            if (e.advName != null && n.kind == 'unknown') {
              n.advName = e.advName;
            }
          }
        }
      }
    }

    // Pass A0: multilateration — an unplaced node seen by ≥2 *placed*
    // observers gets a weighted least-squares position from RSSI
    // path-loss distances. Better than the orbit because it fuses
    // every sighting (watch + phone + node) instead of the single
    // strongest. Solved positions are estimates — flagged so the
    // painter can show an uncertainty ring.
    for (final n in nodes.values) {
      if (n.placed) continue;
      final anchors = <({Offset pos, double d, double w})>[];
      for (final e in edges) {
        if (e.observer != n.id && e.target != n.id) continue;
        final other = e.observer == n.id ? e.target : e.observer;
        final a = nodes[other];
        if (a?.placed != true) continue;
        final d = _rssiRadiusM(e.rssiDbm);
        // Nearby observers dominate — classic WLS weighting.
        anchors.add((pos: a!.pos, d: d, w: 1 / (d * d)));
      }
      if (anchors.length < 2) continue;
      // Weighted-centroid seed, then a few relax iterations pulling the
      // point toward each anchor until radius ≈ path-loss distance.
      var wsum = 0.0;
      var p = Offset.zero;
      for (final a in anchors) {
        p += a.pos * a.w;
        wsum += a.w;
      }
      p /= wsum;
      for (var it = 0; it < 12; it++) {
        var dx = 0.0, dy = 0.0, ws = 0.0;
        for (final a in anchors) {
          final r = (p - a.pos).distance;
          if (r < 0.02) continue;
          final f = a.w * (1 - a.d / r);
          dx += f * (a.pos.dx - p.dx);
          dy += f * (a.pos.dy - p.dy);
          ws += a.w;
        }
        if (ws == 0) break;
        final np = Offset(p.dx + dx / ws, p.dy + dy / ws);
        if ((np - p).distance < 0.001) break;
        p = np;
      }
      n.pos = p;
      n.estimated = true;
    }

    // Position free nodes near their strongest edge's anchor.
    // Pass A: anchored orbit for nodes that touch an anchored device.
    var i = 0;
    for (final n in nodes.values) {
      if (n.placed || n.estimated) continue;
      // strongest edge involving n whose other end is placed
      BleRelation? best;
      for (final e in edges) {
        if (e.observer != n.id && e.target != n.id) continue;
        final other = e.observer == n.id ? e.target : e.observer;
        if (nodes[other]?.placed == true &&
            (best == null || e.rssiDbm > best.rssiDbm)) {
          best = e;
        }
      }
      if (best != null) {
        final other = best.observer == n.id ? best.target : best.observer;
        final a = nodes[other]!.pos;
        final r = _rssiRadiusM(best.rssiDbm) / 6; // visual scale
        final ang = (i * 137.5) * math.pi / 180; // golden-angle spread
        n.pos = a + Offset(math.cos(ang) * r, math.sin(ang) * r);
      }
      i++;
    }
    // Pass B: anything still at origin → loose ring around scene center.
    final placed = nodes.values.where((n) => n.placed).toList();
    final center = placed.isEmpty
        ? const Offset(1.5, 1.0)
        : placed.fold(Offset.zero, (s, n) => s + n.pos) / placed.length.toDouble();
    var j = 0;
    for (final n in nodes.values) {
      if (n.placed || n.pos != Offset.zero) continue;
      final ang = j * 2 * math.pi / math.max(1, nodes.length - placed.length);
      n.pos = center + Offset(2.2 * math.cos(ang), 1.4 * math.sin(ang));
      j++;
    }
    // Fallback for a solitary unplaced node.
    for (final n in nodes.values) {
      if (n.pos == Offset.zero) n.pos = center;
    }

    // User label overrides — applied last so they win over every
    // heuristic (advName, device name, id tail).
    for (final n in nodes.values) {
      final o = labelOverrides[n.id];
      if (o != null && o.isNotEmpty) n.label = o;
    }

    // Unknown-flag pass: anonymous subjects render hollow — but a
    // ble:<MAC> that matches a paired watch is enrolled, not unknown.
    for (final n in nodes.values) {
      if (n.id.startsWith('ble:')) {
        final raw = n.id.substring(4);
        n.known = watchNames.containsKey(raw);
      } else if (n.id.startsWith('device:ble:')) {
        n.known = false;
      }
    }

    // ── 3. Enrich: side ordering + moving flag.
    for (final s in spaces) {
      final inSpace = nodes.values
          .where((n) => n.placed &&
              s.placements.any((p) => '${p['device_id']}' == n.id))
          .toList()
        ..sort((a, b) => a.pos.dx.compareTo(b.pos.dx));
      for (var k = 0; k < inSpace.length; k++) {
        inSpace[k].side = inSpace.length == 1
            ? 'center'
            : k == 0
                ? 'left'
                : k == inSpace.length - 1
                    ? 'right'
                    : 'middle';
      }
    }
    for (final e in edges) {
      for (final id in [e.observer, e.target]) {
        final n = nodes[id];
        if (n != null && e.moving) n.moving = true;
      }
    }

    return _Scene(nodes, edges, spaceBoxes);
  }

  static String _floorTag(SpaceInfo? s, Map<int, SpaceInfo> byId) {
    if (s == null) return '';
    var depth = 0;
    var cur = s;
    final seen = <int>{};
    while (cur.parentId != null &&
        byId.containsKey(cur.parentId) &&
        seen.add(cur.id)) {
      depth++;
      cur = byId[cur.parentId]!;
    }
    if (depth == 0) return s.name;
    return '${s.name} · +$depth fl';
  }
}

// ── painter ─────────────────────────────────────────────────────────────────

class _BleMapPainter extends CustomPainter {
  _BleMapPainter(this.scene, {this.selectedId});
  final _Scene scene;
  final String? selectedId;

  static const _kindIcons = {
    'phone': '📱',
    'watch': '⌚',
    'tv': '📺',
    'speaker': '🔊',
    'thoth': '📡',
    'unknown': '•',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final world = scene.worldRect();
    final scale = math.min(size.width / (world.width + 0.8),
        size.height / (world.height + 0.8));
    Offset map(Offset w) => Offset(
        (w.dx - world.left - 0.4) * scale +
            (size.width - (world.width + 0.8) * scale) / 2,
        (w.dy - world.top - 0.4) * scale +
            (size.height - (world.height + 0.8) * scale) / 2);

    // Space boxes.
    for (final b in scene.spaceBoxes) {
      final r = Rect.fromLTWH(map(b.rect.topLeft).dx, map(b.rect.topLeft).dy,
          b.rect.width * scale, b.rect.height * scale);
      canvas.drawRect(
          r,
          Paint()
            ..color = Colors.blueGrey.withValues(alpha: 0.06)
            ..style = PaintingStyle.fill);
      canvas.drawRect(
          r,
          Paint()
            ..color = Colors.blueGrey.withValues(alpha: 0.35)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke);
      _text(canvas, b.depth == 0 ? b.name : '${b.name} (floor +${b.depth})',
          r.topLeft + const Offset(6, 4),
          Colors.blueGrey.shade700, 11, bold: true);
    }

    // Edges — selection highlights the tapped node's links.
    for (final e in scene.edges) {
      final a = scene.nodes[e.observer], b = scene.nodes[e.target];
      if (a == null || b == null) continue;
      final touched = selectedId != null &&
          (e.observer == selectedId || e.target == selectedId);
      final dimmed = selectedId != null && !touched;
      final pa = map(a.pos), pb = map(b.pos);
      final fresh = (1 - (e.ageSeconds / 90).clamp(0, 1)).toDouble();
      final strength = ((e.rssiDbm + 95) / 60).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.lerp(Colors.red, Colors.blue, strength)!
            .withValues(alpha: dimmed
                ? 0.08
                : touched
                    ? 0.45 + 0.45 * fresh
                    : 0.2 + 0.55 * fresh)
        ..strokeWidth = (touched ? 1.6 : 1) + 4 * strength
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pa, pb, paint);
      final mid = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2);
      if (!dimmed) {
        _text(canvas, '${e.rssiDbm.round()} dBm', mid,
            Colors.black45, 9);
      }
    }

    // Nodes — selected gets a highlight ring.
    for (final n in scene.nodes.values) {
      final p = map(n.pos);
      final color = _nodeColor(n);
      if (n.id == selectedId) {
        canvas.drawCircle(
            p,
            17,
            Paint()
              ..color = Colors.amber.withValues(alpha: 0.35)
              ..style = PaintingStyle.fill);
      }
      // motion halo
      if (n.moving) {
        canvas.drawCircle(
            p,
            16,
            Paint()
              ..color = Colors.orange.withValues(alpha: 0.25)
              ..style = PaintingStyle.fill);
      }
      // Unknown advertisers render hollow.
      canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = n.known ? color : color.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill);
      if (!n.known) {
        final dash = Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(p, 11, dash);
      }
      canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
      // Multilaterated positions get a dashed uncertainty ring — the
      // estimate is a hint from RSSI, not a floorplan coordinate.
      if (n.estimated) {
        final rp = Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        const segs = 10;
        for (var s = 0; s < segs; s += 2) {
          canvas.drawArc(Rect.fromCircle(center: p, radius: 15),
              s * math.pi / segs * 2 / 2,
              math.pi / segs,
              false, rp);
        }
      }
      _text(canvas, _kindIcons[n.kind] ?? '•',
          p - const Offset(6, 8), Colors.white, 12);
      _text(canvas, n.label, p + const Offset(-14, 13),
          Colors.black87, 10, bold: true);
      final tag = [
        if (!n.known) 'unknown${n.advName != null ? ' · ${n.advName}' : ''}',
        if (n.estimated) '~located',
        if (n.floor.isNotEmpty) n.floor,
        if (n.side.isNotEmpty) n.side,
        if (n.moving) 'moving' else 'stationary',
      ].join(' · ');
      _text(canvas, tag, p + const Offset(-14, 25),
          Colors.black54, 8);
    }
  }

  Color _nodeColor(_Node n) {
    if (!n.known) return Colors.grey;
    switch (n.kind) {
      case 'phone':
        return Colors.deepPurple;
      case 'watch':
        return Colors.teal;
      case 'tv':
        return Colors.indigo;
      case 'speaker':
        return Colors.brown;
      default:
        return AppBlue.value;
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color,
      double size,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_BleMapPainter old) => true;
}

/// Small color constant to avoid importing the app theme here.
class AppBlue {
  static const value = Color(0xFF1E88E5);
}
