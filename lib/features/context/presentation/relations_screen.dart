import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/context_providers.dart';

/// BLE relation map (Part 6 shared concept on mobile): observer→target
/// edges drawn from `ble.proximity.v1` evidence. RSSI is shown as signal
/// strength and freshness — never relabeled as physical distance.
class RelationsScreen extends ConsumerWidget {
  const RelationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edges = ref.watch(bleRelationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('BLE relations')),
      body: edges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('BLE evidence unavailable: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No BLE proximity evidence yet. Enable the BLE source '
                    'in Settings → Sources and enroll a wearable.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    return CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _RelationPainter(list, context),
                    );
                  }),
                ),
                SizedBox(
                  height: 140,
                  child: ListView(children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Live edges (RSSI · age · samples)',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ),
                    for (final e in list)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.bluetooth, size: 16),
                        title: Text('${e.observer} → ${e.target}',
                            style: const TextStyle(fontSize: 12)),
                        subtitle: Text(
                            '${e.rssiDbm.round()} dBm · '
                            '${e.ageSeconds.round()}s · '
                            '×${e.count}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                  ]),
                ),
              ]),
      ),
    );
  }
}

class _RelationPainter extends CustomPainter {
  _RelationPainter(this.edges, this.context);

  final List<BleRelation> edges;
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    final observers = edges.map((e) => e.observer).toSet().toList();
    final targets = edges.map((e) => e.target).toSet().toList();
    final w = size.width, h = size.height;
    final leftX = w * 0.15, rightX = w * 0.85;
    Offset posOf(bool observer, int idx, int total) {
      final y = h * (0.12 + 0.76 * (idx / math.max(1, total - 1)));
      return Offset(observer ? leftX : rightX, y.isFinite ? y : h / 2);
    }

    final observerPos = <String, Offset>{
      for (var i = 0; i < observers.length; i++)
        observers[i]: posOf(true, i, observers.length)
    };
    final targetPos = <String, Offset>{
      for (var i = 0; i < targets.length; i++)
        targets[i]: posOf(false, i, targets.length)
    };

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final e in edges) {
      final a = observerPos[e.observer]!;
      final b = targetPos[e.target]!;
      // Freshness → opacity; RSSI → width. No distance semantics.
      final freshness = (1 - (e.ageSeconds / 90).clamp(0, 1)).toDouble();
      final strength =
          ((e.rssiDbm + 95) / 60).clamp(0.0, 1.0).toDouble();
      edgePaint.color = AppColors.primaryBlue
          .withValues(alpha: 0.15 + 0.6 * freshness);
      edgePaint.strokeWidth = 1 + 3 * strength;
      canvas.drawLine(a, b, edgePaint);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      _label(canvas, '${e.rssiDbm.round()}', mid, Colors.black54, 10);
    }

    void node(String label, Offset p, bool observer) {
      final fill = Paint()
        ..color = observer ? AppColors.primaryBlue : Colors.teal;
      canvas.drawCircle(p, 16, fill);
      _label(canvas, label,
          p + Offset(observer ? -58 : 20, -5), Colors.black87, 11);
      final icon = TextPainter(
        text: TextSpan(
            text: observer ? '◉' : '◌',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(canvas, p - Offset(icon.width / 2, icon.height / 2));
    }

    observerPos.forEach((k, p) => node(k.split(':').last, p, true));
    targetPos.forEach((k, p) => node(k.split(':').last, p, false));
  }

  void _label(Canvas canvas, String text, Offset at, Color color,
      double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RelationPainter old) => true;
}
