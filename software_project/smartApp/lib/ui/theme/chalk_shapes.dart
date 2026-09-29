import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Organic, gently-irregular blob fill — used in place of plain rounded
/// rectangles for the hero card background, subject icon backgrounds, and
/// the recommended-lessons spotlight accent.
///
/// The blob is built from a fixed ring of anchor points (radius varying per
/// [variant], not random, so it's reproducible) connected by quadratic
/// Bezier curves through their midpoints — a standard smooth-blob technique.
class ChalkBlobPainter extends CustomPainter {
  const ChalkBlobPainter({required this.color, this.variant = 0});

  final Color color;
  final int variant;

  static const List<List<double>> _radiusFactors = [
    [0.88, 0.99, 0.84, 0.96, 0.86, 1.00, 0.85, 0.94],
    [0.92, 0.83, 0.99, 0.87, 0.97, 0.84, 0.95, 0.89],
    [0.85, 0.96, 0.88, 1.00, 0.83, 0.98, 0.90, 0.86],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final factors = _radiusFactors[variant % _radiusFactors.length];
    final n = factors.length;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2 * 0.98;
    final ry = size.height / 2 * 0.98;

    final points = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          cx +
              rx *
                  factors[i] *
                  math.cos(2 * math.pi * i / n - math.pi / 2),
          cy +
              ry *
                  factors[i] *
                  math.sin(2 * math.pi * i / n - math.pi / 2),
        ),
    ];

    final path = _smoothClosedPath(points);
    canvas.drawPath(path, Paint()..color = color);
  }

  static Path _smoothClosedPath(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    Offset mid(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final start = mid(pts[n - 1], pts[0]);
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final cur = pts[i];
      final next = pts[(i + 1) % n];
      final m = mid(cur, next);
      path.quadraticBezierTo(cur.dx, cur.dy, m.dx, m.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant ChalkBlobPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.variant != variant;
}

/// Partial-circle progress arc — used for a subject card's skill-level
/// indicator and for the circular "chalk ring" rows in Your Progress.
class ChalkArcPainter extends CustomPainter {
  const ChalkArcPainter({
    required this.progress,
    required this.color,
    this.trackColor = const Color(0x1A1B1B1F),
    this.strokeWidth = 6,
  });

  /// 0..1
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant ChalkArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Rounded-rect clip with a small triangular tail, so a plain container reads
/// as an actual speech-bubble shape (used for Chat History rows).
class ChatBubbleClipper extends CustomClipper<Path> {
  const ChatBubbleClipper({this.radius = 16, this.tailSize = 10, this.tailInset = 24});

  final double radius;
  final double tailSize;
  final double tailInset;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - tailSize),
        Radius.circular(radius),
      ))
      ..moveTo(tailInset, size.height - tailSize)
      ..lineTo(tailInset + tailSize * 1.4, size.height - tailSize)
      ..lineTo(tailInset + tailSize * 0.4, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant ChatBubbleClipper oldClipper) =>
      oldClipper.radius != radius ||
      oldClipper.tailSize != tailSize ||
      oldClipper.tailInset != tailInset;
}

/// Wraps [child] with a brief scale-down on tap-down / back up on release —
/// mobile touch feedback (no hover state to lean on).
class ChalkTapScale extends StatefulWidget {
  const ChalkTapScale({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedScale = 0.96,
  });

  final VoidCallback onTap;
  final Widget child;
  final double pressedScale;

  @override
  State<ChalkTapScale> createState() => _ChalkTapScaleState();
}

class _ChalkTapScaleState extends State<ChalkTapScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
