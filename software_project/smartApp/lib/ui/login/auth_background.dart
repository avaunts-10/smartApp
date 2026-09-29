import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Full-screen decorative background for the login / register screens.
///
/// Pure code — no image assets. A deep-blue room: a light animated IoT network
/// and dashboard read-outs overhead, and a clearly drawn smart classroom along
/// the bottom — a teacher at an interactive board teaching rows of students,
/// surrounded by connected devices (projector, sensors, Wi-Fi, camera…).
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1A45), Color(0xFF122F72), Color(0xFF2D66F6)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _Blob(
              alignment: Alignment(-1.1, -1.0),
              size: 420,
              color: Color(0x554DA3FF)),
          const _Blob(
              alignment: Alignment(1.2, -0.5),
              size: 360,
              color: Color(0x4422D3EE)),
          const _Blob(
              alignment: Alignment(-0.7, 1.25),
              size: 480,
              color: Color(0x448B5CF6)),

          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) =>
                    CustomPaint(painter: _SmartClassroomPainter(_c.value)),
              ),
            ),
          ),

          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0F000000), Color(0x3306122E)],
                ),
              ),
            ),
          ),

          widget.child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(
      {required this.alignment, required this.size, required this.color});

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

double _frac(double v) => v - v.floorToDouble();

class _SmartClassroomPainter extends CustomPainter {
  _SmartClassroomPainter(this.t);

  final double t;

  // Palette
  static const _cyan = Color(0xFF34D9F0);
  static const _sky = Color(0xFF9CC6FF);
  static const _warm = Color(0xFFFFE29A);
  static const _green = Color(0xFF7DE7BE);
  static const _deskTop = Color(0xFF3E63C8);
  static const _deskBody = Color(0xFF1B3A82);
  static const _wall = Color(0xFF11265E);
  static const _wallDeep = Color(0xFF0A1C46);

  static final Map<String, TextPainter> _tpCache = {};

  TextPainter _tp(String s, double size, Color color,
      {FontWeight w = FontWeight.w600}) {
    final key = '$s|$size|${color.value}|${w.index}';
    return _tpCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: color, fontWeight: w),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  static const _nodes = <Offset>[
    Offset(0.08, 0.08), Offset(0.20, 0.17), Offset(0.13, 0.28),
    Offset(0.34, 0.07), Offset(0.44, 0.18), Offset(0.30, 0.25),
    Offset(0.58, 0.10), Offset(0.69, 0.21), Offset(0.55, 0.28),
    Offset(0.81, 0.08), Offset(0.91, 0.19), Offset(0.80, 0.30),
  ];
  static const _edges = <List<int>>[
    [0, 1], [1, 2], [1, 3], [3, 4], [4, 5], [5, 2],
    [4, 6], [6, 7], [7, 8], [8, 4], [7, 9], [9, 10], [10, 11], [11, 7],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintNetwork(canvas, size);
    _paintReadouts(canvas, size);
    _paintClassroom(canvas, size);
  }

  // ---------------------------------------------------------------- network --
  void _paintNetwork(Canvas canvas, Size size) {
    Offset p(int i) =>
        Offset(_nodes[i].dx * size.width, _nodes[i].dy * size.height);

    final line = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;
    for (final e in _edges) {
      canvas.drawLine(p(e[0]), p(e[1]), line);
    }

    const pulseEdges = [0, 4, 8, 11];
    for (var k = 0; k < pulseEdges.length; k++) {
      final e = _edges[pulseEdges[k]];
      final f = _frac(t + k / pulseEdges.length);
      final pos = Offset.lerp(p(e[0]), p(e[1]), f)!;
      canvas.drawCircle(pos, 2.2, Paint()..color = _cyan.withOpacity(0.8));
      canvas.drawCircle(pos, 5.5, Paint()..color = _cyan.withOpacity(0.12));
    }

    for (var i = 0; i < _nodes.length; i++) {
      final tw = 0.5 + 0.5 * math.sin((t * 2 * math.pi) + i);
      canvas.drawCircle(p(i), 2.4,
          Paint()..color = Colors.white.withOpacity(0.15 + 0.2 * tw));
    }

    _wifi(canvas, p(3), 14, _sky.withOpacity(0.3));
    _wifi(canvas, p(9), 12, _cyan.withOpacity(0.28));

    _glyphCap(canvas, p(2), 12, _sky.withOpacity(0.45));
    _glyphBook(canvas, p(6), 11, _cyan.withOpacity(0.4));

    final bob = 3 * math.sin(t * 2 * math.pi);
    _robot(canvas, Offset(size.width * 0.945, size.height * 0.13 + bob));
  }

  void _wifi(Canvas canvas, Offset o, double step, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(Rect.fromCircle(center: o, radius: step * i),
          math.pi * 1.25, math.pi * 0.5, false, paint);
    }
    canvas.drawCircle(o, 2, Paint()..color = color.withOpacity(0.9));
  }

  void _glyphCap(Canvas canvas, Offset o, double s, Color col) {
    final path = Path()
      ..moveTo(o.dx - s, o.dy)
      ..lineTo(o.dx, o.dy - s * 0.55)
      ..lineTo(o.dx + s, o.dy)
      ..lineTo(o.dx, o.dy + s * 0.55)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawLine(Offset(o.dx + s, o.dy), Offset(o.dx + s, o.dy + s * 0.7),
        Paint()
          ..color = col
          ..strokeWidth = 1.4);
  }

  void _glyphBook(Canvas canvas, Offset o, double s, Color col) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = col;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: o, width: s * 1.6, height: s * 1.2),
          const Radius.circular(2)),
      p,
    );
    canvas.drawLine(
        Offset(o.dx, o.dy - s * 0.6), Offset(o.dx, o.dy + s * 0.6), p);
  }

  // ------------------------------------------------------------- read-outs ---
  void _paintReadouts(Canvas canvas, Size size) {
    final w = size.width;
    _chip(canvas, Offset(w * 0.05, size.height * 0.09), Icons.thermostat,
        '23.4°C', _warm);
    _chip(canvas, Offset(w * 0.05, size.height * 0.09 + 32),
        Icons.water_drop_outlined, '45% RH', _sky);
    _chip(canvas, Offset(w * 0.79, size.height * 0.075),
        Icons.groups_outlined, '28 / 30', _green);
    _chip(canvas, Offset(w * 0.79, size.height * 0.075 + 32), Icons.co2,
        '480 ppm', _cyan);
  }

  void _chip(Canvas canvas, Offset at, IconData icon, String value, Color tint) {
    final tp = _tp(value, 11, Colors.white.withOpacity(0.8));
    final iconTp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 13,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: tint.withOpacity(0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final wChip = 22 + iconTp.width + 6 + tp.width;
    final rect = Rect.fromLTWH(at.dx, at.dy, wChip, 24);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = const Color(0xFF0A1C46).withOpacity(0.55));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withOpacity(0.4),
    );
    iconTp.paint(canvas, Offset(at.dx + 7, at.dy + 5));
    tp.paint(canvas, Offset(at.dx + 15 + iconTp.width + 3, at.dy + 6));
  }

  // ------------------------------------------------------------- classroom ---
  void _paintClassroom(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, 1100) / 1100;
    final floorY = h * 0.82;
    final wallTop = h * 0.30;

    // Room: back wall + floor.
    canvas.drawRect(Rect.fromLTRB(0, wallTop, w, floorY),
        Paint()..color = _wall.withOpacity(0.30));
    canvas.drawRect(Rect.fromLTRB(0, floorY, w, h),
        Paint()..color = _wallDeep.withOpacity(0.78));
    // wall / floor seam
    canvas.drawLine(Offset(0, floorY), Offset(w, floorY),
        Paint()
          ..color = _cyan.withOpacity(0.12)
          ..strokeWidth = 1);
    final vp = Offset(w * 0.5, floorY - 70 * u);
    final fl = Paint()
      ..color = _cyan.withOpacity(0.06)
      ..strokeWidth = 1;
    for (final fx in [0.0, 0.22, 0.42, 0.58, 0.78, 1.0]) {
      canvas.drawLine(Offset(fx * w, h), vp, fl);
    }

    // Ceiling tech.
    for (final lx in [0.44, 0.60, 0.76]) {
      _pendant(canvas, Offset(w * lx, wallTop - 22 * u), wallTop + 2 * u, u);
    }
    _motionSensor(canvas, Offset(w * 0.97, wallTop + 2 * u), u);

    // ---- Interactive board on the front wall ----
    final board = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.035, wallTop + 6 * u, math.max(190, w * 0.23),
          h * 0.27),
      Radius.circular(10 * u),
    );
    canvas.drawRRect(board, Paint()..color = _wallDeep.withOpacity(0.92));
    canvas.drawRRect(
        board,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _cyan.withOpacity(0.55));
    _boardContent(canvas, board.outerRect, u);

    // ---- Big, friendly people — the focal point of the scene ----

    // Back row (smaller, further away).
    _studentRow(canvas, w, floorY - 86 * u, u,
        startX: w * 0.40, count: 4, gap: 124 * u, scale: 1.5, raiseHand: -1,
        seed: 4);

    // Teacher, large, at the board.
    _teacher(canvas, Offset(board.right + 34 * u, floorY - 2 * u), 2.4 * u,
        pointAt: Offset(board.right - 18 * u, board.bottom - h * 0.05));

    // Front row (large, close to the viewer).
    _studentRow(canvas, w, floorY + 4 * u, u,
        startX: w * 0.40, count: 4, gap: 150 * u, scale: 2.5, raiseHand: 1,
        seed: 0);
    // A couple more on the open left side, under the board.
    _studentRow(canvas, w, floorY + 2 * u, u,
        startX: w * 0.045, count: 2, gap: 120 * u, scale: 2.2, raiseHand: -1,
        seed: 2);

    // Face-recognition attendance frame over a front-row student.
    _faceScan(canvas, Offset(w * 0.40 + 150 * u, floorY - 104 * u), 22 * u);

    // ---- Wall devices along the right edge ----
    _thermometer(canvas, Offset(w * 0.965, wallTop + 22 * u), u);
    _router(canvas, Offset(w * 0.945, wallTop + 64 * u), u);
    _camera(canvas, Offset(w * 0.035, wallTop + 16 * u), u, flip: true);
    _speaker(canvas, Offset(w * 0.97, wallTop + 100 * u), u);
    _plant(canvas, Offset(w * 0.02, floorY), u);
  }

  void _boardContent(Canvas canvas, Rect r, double u) {
    final pad = 14 * u;
    final area =
        Rect.fromLTRB(r.left + pad, r.top + pad + 14 * u, r.right - pad,
            r.bottom - pad);

    _tp('TODAY’S LESSON', 11 * u, _cyan.withOpacity(0.85),
            w: FontWeight.w800)
        .paint(canvas, Offset(r.left + pad, r.top + pad));

    final barW = area.width / 10;
    const heights = [0.4, 0.6, 0.5, 0.78, 0.66, 0.9];
    for (var i = 0; i < heights.length; i++) {
      final bh = area.height * heights[i] * 0.9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                area.left + i * barW * 1.35, area.bottom - bh, barW, bh),
            Radius.circular(2 * u)),
        Paint()..color = _sky.withOpacity(0.4),
      );
    }
    final path = Path();
    const pts = [0.72, 0.55, 0.62, 0.34, 0.4, 0.16, 0.1];
    for (var i = 0; i < pts.length; i++) {
      final px = area.left + area.width * (i / (pts.length - 1));
      final py = area.top + area.height * pts[i];
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * u
        ..strokeCap = StrokeCap.round
        ..color = _cyan.withOpacity(0.95),
    );
  }

  // ---- friendly flat-illustration people -------------------------------
  static const _figSkin = <Color>[
    Color(0xFFBAD4FF), Color(0xFF9FE7DF), Color(0xFFCBBEF7),
    Color(0xFFFFD9A6), Color(0xFFA7C8FF), Color(0xFFF4B9D2),
  ];

  Color _figCol(int i, double o) =>
      _figSkin[i % _figSkin.length].withOpacity(o);

  /// Draws a friendly rounded head + soft-shouldered torso standing on [base].
  /// Returns the shoulder-centre point (for attaching arms).
  Offset _upperBody(Canvas canvas, Offset base, double s, Color col,
      {double torsoH = 22}) {
    final headR = 7.5 * s;
    final shoulderY = base.dy - torsoH * s;
    final torso = Path()
      ..moveTo(base.dx - 13 * s, base.dy)
      ..cubicTo(base.dx - 13 * s, shoulderY, base.dx - 8 * s, shoulderY,
          base.dx, shoulderY)
      ..cubicTo(base.dx + 8 * s, shoulderY, base.dx + 13 * s, shoulderY,
          base.dx + 13 * s, base.dy)
      ..close();
    canvas.drawPath(torso, Paint()..color = col);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(base.dx - 2 * s, shoulderY - 4 * s, 4 * s, 6 * s),
          Radius.circular(1.5 * s)),
      Paint()..color = col,
    );
    canvas.drawCircle(Offset(base.dx, shoulderY - headR - 1 * s), headR,
        Paint()..color = col);
    return Offset(base.dx, shoulderY);
  }

  void _teacher(Canvas canvas, Offset feet, double s, {required Offset pointAt}) {
    final col = _figCol(1, 0.9);
    final hipY = feet.dy - 24 * s;
    final limb = Paint()
      ..color = col
      ..strokeWidth = 5.5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(feet.dx - 1 * s, hipY), Offset(feet.dx - 6 * s, feet.dy), limb);
    canvas.drawLine(
        Offset(feet.dx + 1 * s, hipY), Offset(feet.dx + 6 * s, feet.dy), limb);

    final shoulder =
        _upperBody(canvas, Offset(feet.dx, hipY + 2 * s), s, col, torsoH: 30);

    // resting near-arm
    canvas.drawLine(Offset(shoulder.dx + 9 * s, shoulder.dy + 3 * s),
        Offset(shoulder.dx + 12 * s, shoulder.dy + 20 * s), limb);

    // pointing arm + pointer toward the board
    var dir = pointAt - shoulder;
    final len = dir.distance;
    dir = len == 0 ? const Offset(-1, 0) : dir / len;
    final hand =
        Offset(shoulder.dx - 8 * s, shoulder.dy + 2 * s) + dir * (14 * s);
    canvas.drawLine(
        Offset(shoulder.dx - 8 * s, shoulder.dy + 3 * s), hand, limb);
    canvas.drawLine(
        hand,
        pointAt,
        Paint()
          ..color = _warm.withOpacity(0.8)
          ..strokeWidth = 2 * s
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(pointAt, 2.5 * s, Paint()..color = _warm.withOpacity(0.9));
  }

  void _studentRow(Canvas canvas, double w, double baseY, double u,
      {required double startX,
      required int count,
      required double gap,
      required double scale,
      required int raiseHand,
      int seed = 0}) {
    for (var i = 0; i < count; i++) {
      final x = startX + i * gap;
      if (x > w + 30) break;
      _deskWithStudent(canvas, Offset(x, baseY), scale * u, u,
          colorIndex: seed + i,
          hand: i == 1 && raiseHand > 0,
          lit: (seed + i).isEven);
    }
  }

  void _deskWithStudent(Canvas canvas, Offset feet, double s, double u,
      {required int colorIndex, required bool hand, required bool lit}) {
    final col = _figCol(colorIndex, 0.74);
    final shoulder = _upperBody(canvas, feet, s, col, torsoH: 21);
    final limb = Paint()
      ..color = col
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round;
    if (hand) {
      canvas.drawLine(Offset(shoulder.dx - 5 * s, shoulder.dy + 3 * s),
          Offset(shoulder.dx - 11 * s, shoulder.dy - 20 * s), limb);
      canvas.drawCircle(Offset(shoulder.dx - 11 * s, shoulder.dy - 23 * s),
          3 * s, Paint()..color = col);
    } else {
      canvas.drawLine(Offset(shoulder.dx - 7 * s, shoulder.dy + 4 * s),
          Offset(shoulder.dx - 12 * s, feet.dy - 6 * s), limb);
    }

    // desk in front of the student
    final dW = 32 * s;
    final dTop = feet.dy - 6 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(feet.dx - dW / 2, dTop, dW, 6 * s),
          Radius.circular(2 * u)),
      Paint()..color = _deskTop.withOpacity(0.95),
    );
    canvas.drawRect(
        Rect.fromLTWH(feet.dx - dW / 2 + 2 * s, dTop + 6 * s, 3 * s, 15 * s),
        Paint()..color = _deskBody.withOpacity(0.95));
    canvas.drawRect(
        Rect.fromLTWH(feet.dx + dW / 2 - 5 * s, dTop + 6 * s, 3 * s, 15 * s),
        Paint()..color = _deskBody.withOpacity(0.95));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(feet.dx - 7 * s, dTop - 8 * s, 14 * s, 8 * s),
          Radius.circular(1.5 * u)),
      Paint()..color = (lit ? _cyan : _sky).withOpacity(lit ? 0.6 : 0.32),
    );
  }

  void _faceScan(Canvas canvas, Offset c, double s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = _green.withOpacity(0.85);
    const k = 0.4;
    void bracket(double sx, double sy) {
      final cx = c.dx + sx * s, cy = c.dy + sy * s;
      canvas.drawLine(Offset(cx, cy), Offset(cx - sx * s * k, cy), p);
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy - sy * s * k), p);
    }

    bracket(-1, -1);
    bracket(1, -1);
    bracket(-1, 1);
    bracket(1, 1);
    final sweepY = c.dy - s + 2 * s * _frac(t * 2);
    canvas.drawLine(Offset(c.dx - s, sweepY), Offset(c.dx + s, sweepY),
        Paint()
          ..color = _green.withOpacity(0.4)
          ..strokeWidth = 1);
    _tp('✓', 9 * (s / 15), _green.withOpacity(0.9))
        .paint(canvas, Offset(c.dx + s * 0.55, c.dy - s * 1.35));
  }

  // ---- devices ---------------------------------------------------------
  void _pendant(Canvas canvas, Offset top, double dropTo, double u) {
    canvas.drawLine(top, Offset(top.dx, dropTo),
        Paint()
          ..color = Colors.white.withOpacity(0.14)
          ..strokeWidth = 1);
    final bulb = Offset(top.dx, dropTo);
    final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi + top.dx);
    canvas.drawCircle(bulb, (12 + 4 * glow) * u,
        Paint()..color = _warm.withOpacity(0.06 + 0.05 * glow));
    canvas.drawCircle(bulb, 5 * u, Paint()..color = _warm.withOpacity(0.22));
    canvas.drawCircle(bulb, 2.6 * u, Paint()..color = _warm.withOpacity(0.65));
  }

  void _motionSensor(Canvas canvas, Offset o, double u) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: o, width: 16 * u, height: 12 * u),
            Radius.circular(3 * u)),
        Paint()..color = _wall.withOpacity(0.95));
    final cone = Path()
      ..moveTo(o.dx, o.dy + 6 * u)
      ..lineTo(o.dx - 70 * u, o.dy + 60 * u)
      ..lineTo(o.dx + 10 * u, o.dy + 84 * u)
      ..close();
    canvas.drawPath(cone, Paint()..color = _green.withOpacity(0.06));
    final blink = math.sin(t * 6 * math.pi) > 0 ? 0.9 : 0.25;
    canvas.drawCircle(Offset(o.dx, o.dy + 2 * u), 1.7 * u,
        Paint()..color = _green.withOpacity(blink));
  }

  void _thermometer(Canvas canvas, Offset c, double u) {
    final stem = Rect.fromCenter(center: c, width: 7 * u, height: 22 * u);
    canvas.drawRRect(
        RRect.fromRectAndRadius(stem, Radius.circular(4 * u)),
        Paint()..color = _wall.withOpacity(0.95));
    canvas.drawCircle(Offset(c.dx, c.dy + 15 * u), 6 * u,
        Paint()..color = _warm.withOpacity(0.75));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy + 3 * u), width: 3 * u, height: 14 * u),
          Radius.circular(2 * u)),
      Paint()..color = _warm.withOpacity(0.75),
    );
  }

  void _router(Canvas canvas, Offset c, double u) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 34 * u, height: 12 * u),
            Radius.circular(3 * u)),
        Paint()..color = _wall.withOpacity(0.95));
    canvas.drawCircle(Offset(c.dx - 8 * u, c.dy), 1.7 * u,
        Paint()..color = _cyan.withOpacity(0.95));
    canvas.drawCircle(
        Offset(c.dx, c.dy), 1.7 * u, Paint()..color = _warm.withOpacity(0.85));
    canvas.drawLine(
        Offset(c.dx + 10 * u, c.dy - 6 * u),
        Offset(c.dx + 14 * u, c.dy - 16 * u),
        Paint()
          ..color = Colors.white.withOpacity(0.28)
          ..strokeWidth = 1.5);
    _wifi(canvas, Offset(c.dx + 14 * u, c.dy - 16 * u), 8 * u,
        _cyan.withOpacity(0.4));
  }

  void _camera(Canvas canvas, Offset c, double u, {bool flip = false}) {
    final d = flip ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + d * 18 * u, c.dy - 8 * u)
      ..lineTo(c.dx + d * 18 * u, c.dy + 8 * u)
      ..close();
    canvas.drawPath(path, Paint()..color = _wall.withOpacity(0.95));
    canvas.drawCircle(Offset(c.dx + d * 14 * u, c.dy), 3 * u,
        Paint()..color = _cyan.withOpacity(0.75));
  }

  void _speaker(Canvas canvas, Offset o, double u) {
    canvas.drawCircle(o, 8 * u, Paint()..color = _wall.withOpacity(0.95));
    canvas.drawCircle(o, 3 * u, Paint()..color = _sky.withOpacity(0.45));
    final ring = 0.5 + 0.5 * math.sin(t * 3 * math.pi);
    canvas.drawCircle(
      o,
      (8 + 8 * ring) * u,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _sky.withOpacity(0.22 * (1 - ring)),
    );
  }

  void _plant(Canvas canvas, Offset base, double u) {
    final pot = Path()
      ..moveTo(base.dx - 10 * u, base.dy - 16 * u)
      ..lineTo(base.dx + 10 * u, base.dy - 16 * u)
      ..lineTo(base.dx + 7 * u, base.dy)
      ..lineTo(base.dx - 7 * u, base.dy)
      ..close();
    canvas.drawPath(pot, Paint()..color = _wall.withOpacity(0.95));
    final leaf = Paint()..color = _green.withOpacity(0.32);
    for (final a in [-0.6, 0.0, 0.6]) {
      canvas.save();
      canvas.translate(base.dx, base.dy - 16 * u);
      canvas.rotate(a);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, -13 * u), width: 9 * u, height: 26 * u),
          leaf);
      canvas.restore();
    }
  }

  void _robot(Canvas canvas, Offset c) {
    final head = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 34, height: 28),
        const Radius.circular(9));
    canvas.drawRRect(head, Paint()..color = _wall.withOpacity(0.9));
    canvas.drawRRect(
        head,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _cyan.withOpacity(0.55));
    final blink = math.sin(t * 2 * math.pi) > 0.94 ? 0.4 : 1.0;
    final eye = Paint()..color = _cyan.withOpacity(0.95 * blink);
    canvas.drawCircle(Offset(c.dx - 7, c.dy), 2.6, eye);
    canvas.drawCircle(Offset(c.dx + 7, c.dy), 2.6, eye);
    canvas.drawLine(Offset(c.dx, c.dy - 14), Offset(c.dx, c.dy - 20),
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..strokeWidth = 1.3);
    canvas.drawCircle(
        Offset(c.dx, c.dy - 21), 2, Paint()..color = _warm.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _SmartClassroomPainter old) => old.t != t;
}
