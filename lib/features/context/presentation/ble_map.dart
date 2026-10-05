import 'dart:math' as math;

import 'package:flutter/material.dart';

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
class BleMapView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scene = _Scene.build(
        edges: edges,
        devices: devices,
        spaces: spaces,
        watchNames: watchNames);
    return CustomPaint(
      painter: _BleMapPainter(scene),
      child: const SizedBox.expand(),
    );
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
  final String label;
  final String kind; // phone | watch | thoth | tv | speaker | unknown
  Offset pos;
  String floor;
  bool moving = false;
  bool placed;
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
        final isWatch = RegExp(r'^([0-9A-Fa-f]{2}:){5}').hasMatch(raw) ||
            watchNames.containsKey(raw);
        nodes[k] = _Node(
          id: k,
          label: d?.name ??
              watchNames[raw] ??
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

    // Position free nodes near their strongest edge's anchor.
    // Pass A: anchored orbit for nodes that touch an anchored device.
    var i = 0;
    for (final n in nodes.values) {
      if (n.placed) continue;
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

    // Unknown-flag pass: node rows also mark subjects anonymous.
    for (final n in nodes.values) {
      if (n.id.startsWith('ble:') || n.id.startsWith('device:ble:')) {
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
  _BleMapPainter(this.scene);
  final _Scene scene;

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
    final world = _worldRect();
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

    // Edges.
    for (final e in scene.edges) {
      final a = scene.nodes[e.observer], b = scene.nodes[e.target];
      if (a == null || b == null) continue;
      final pa = map(a.pos), pb = map(b.pos);
      final fresh = (1 - (e.ageSeconds / 90).clamp(0, 1)).toDouble();
      final strength = ((e.rssiDbm + 95) / 60).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.lerp(Colors.red, Colors.blue, strength)!
            .withValues(alpha: 0.2 + 0.55 * fresh)
        ..strokeWidth = 1 + 4 * strength
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pa, pb, paint);
      final mid = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2);
      _text(canvas, '${e.rssiDbm.round()} dBm', mid,
          Colors.black45, 9);
    }

    // Nodes.
    for (final n in scene.nodes.values) {
      final p = map(n.pos);
      final color = _nodeColor(n);
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
      _text(canvas, _kindIcons[n.kind] ?? '•',
          p - const Offset(6, 8), Colors.white, 12);
      _text(canvas, n.label, p + const Offset(-14, 13),
          Colors.black87, 10, bold: true);
      final tag = [
        if (!n.known) 'unknown${n.advName != null ? ' · ${n.advName}' : ''}',
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

  Rect _worldRect() {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    void grow(Offset p) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }

    for (final n in scene.nodes.values) {
      grow(n.pos);
    }
    for (final s in scene.spaceBoxes) {
      grow(s.rect.topLeft);
      grow(s.rect.bottomRight);
    }
    if (!l.isFinite) return const Rect.fromLTWH(0, 0, 3, 2);
    return Rect.fromLTRB(l, t, r, b);
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
