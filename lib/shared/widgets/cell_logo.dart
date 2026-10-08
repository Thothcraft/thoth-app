import 'package:flutter/material.dart';

/// Thoth Cell mark — an isometric cube of three sensing faces on a 3×3
/// lattice, with a nucleus at the shared vertex: many sensors, one
/// context. Identical geometry to the site / hub / dashboard / watch mark.
class CellLogo extends StatelessWidget {
  const CellLogo({
    super.key,
    this.size = 30,
    this.brightness = Brightness.light,
    this.pulse = 0,
  });

  final double size;
  final Brightness brightness;

  /// 0..1 — nucleus ring expansion for the loading/boot state.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark ||
        Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: Size.square(size),
      painter: CellLogoPainter(dark: dark, pulse: pulse),
    );
  }
}

/// Spins the nucleus pulse; drop-in for CircularProgressIndicator-branding.
class CellLoader extends StatefulWidget {
  const CellLoader({super.key, this.size = 56, this.label});

  final double size;
  final String? label;

  @override
  State<CellLoader> createState() => _CellLoaderState();
}

class _CellLoaderState extends State<CellLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final mark = AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CellLogo(size: widget.size, pulse: _c.value),
    );
    if (label == null) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class CellLogoPainter extends CustomPainter {
  CellLogoPainter({required this.dark, this.pulse = 0});

  final bool dark;
  final double pulse;

  // 64×64 viewBox geometry (shared with web cell-geometry.ts).
  static const _top = [Offset(32, 6), Offset(54.5, 19), Offset(32, 32), Offset(9.5, 19)];
  static const _left = [Offset(9.5, 19), Offset(32, 32), Offset(32, 58), Offset(9.5, 45)];
  static const _right = [Offset(32, 32), Offset(54.5, 19), Offset(54.5, 45), Offset(32, 58)];
  static const _lattice = <(double, double, double, double, bool)>[
    (24.5, 10.33, 47.0, 23.33, false), (17.0, 14.67, 39.5, 27.67, false),
    (39.5, 10.33, 17.0, 23.33, false), (47.0, 14.67, 24.5, 27.67, false),
    (9.5, 27.67, 32.0, 40.67, true), (9.5, 36.33, 32.0, 49.33, true),
    (17.0, 23.33, 17.0, 49.33, true), (24.5, 27.67, 24.5, 53.67, true),
    (32.0, 40.67, 54.5, 27.67, false), (32.0, 49.33, 54.5, 36.33, false),
    (39.5, 27.67, 39.5, 53.67, false), (47.0, 23.33, 47.0, 49.33, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    Offset p(Offset o) => Offset(o.dx * s, o.dy * s);

    Path face(List<Offset> pts) => Path()
      ..moveTo(pts[0].dx * s, pts[0].dy * s)
      ..lineTo(pts[1].dx * s, pts[1].dy * s)
      ..lineTo(pts[2].dx * s, pts[2].dy * s)
      ..lineTo(pts[3].dx * s, pts[3].dy * s)
      ..close();

    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = dark ? const Color(0xFF3A372E) : const Color(0xFFE9E2D0);
    canvas.drawPath(face(_top), paint);
    paint.color = dark ? const Color(0xFFF4F1E9) : const Color(0xFF11110F);
    canvas.drawPath(face(_left), paint);
    paint.color = const Color(0xFFA3502E);
    canvas.drawPath(face(_right), paint);

    final latDark = Paint()
      ..strokeWidth = 0.9 * s
      ..strokeCap = StrokeCap.round
      ..color = dark
          ? const Color(0x52171A15)
          : const Color(0x52F4F1E9);
    final latLight = Paint()
      ..strokeWidth = 0.9 * s
      ..strokeCap = StrokeCap.round
      ..color = dark
          ? const Color(0x52F4F1E9)
          : const Color(0x5217110F);
    for (final (x1, y1, x2, y2, onLeft) in _lattice) {
      canvas.drawLine(
        Offset(x1 * s, y1 * s),
        Offset(x2 * s, y2 * s),
        onLeft ? latDark : latLight,
      );
    }

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s
      ..strokeJoin = StrokeJoin.round
      ..color = dark ? const Color(0xFFF4F1E9) : const Color(0xFF11110F);
    final hex = Path()
      ..moveTo(32 * s, 6 * s)
      ..lineTo(54.5 * s, 19 * s)
      ..lineTo(54.5 * s, 45 * s)
      ..lineTo(32 * s, 58 * s)
      ..lineTo(9.5 * s, 45 * s)
      ..lineTo(9.5 * s, 19 * s)
      ..close();
    canvas.drawPath(hex, edge);

    final nucleus = p(const Offset(32, 32));
    const nucleusColor = Color(0xFFF4F1E9);
    if (pulse > 0) {
      canvas.drawCircle(
        nucleus,
        (5 + 5 * pulse) * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * s
          ..color = nucleusColor.withValues(alpha: 0.7 * (1 - pulse)),
      );
    }
    paint.color = nucleusColor;
    canvas.drawCircle(nucleus, 4 * s, paint);
  }

  @override
  bool shouldRepaint(CellLogoPainter old) =>
      old.dark != dark || old.pulse != pulse;
}
