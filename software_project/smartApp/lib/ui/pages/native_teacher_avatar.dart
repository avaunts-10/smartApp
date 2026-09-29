import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'teacher3d_view.dart';

/// Native fallback for the web-only 3D avatar: a lightweight hand-drawn
/// teacher (CustomPainter, no WebGL/WebView) that speaks replies with
/// on-device TTS and opens/closes its mouth in time with the words —
/// mirroring the web avatar's word-boundary-driven lip-sync
/// (`wordToVisemes()` there, `FlutterTts.setProgressHandler` here).
class NativeTeacherAvatar extends StatefulWidget {
  const NativeTeacherAvatar({
    super.key,
    required this.initialGender,
    this.controller,
  });

  final String initialGender; // 'female' or 'male'
  final Teacher3dController? controller;

  @override
  State<NativeTeacherAvatar> createState() => _NativeTeacherAvatarState();
}

class _NativeTeacherAvatarState extends State<NativeTeacherAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  final FlutterTts _tts = FlutterTts();
  late String _gender = widget.initialGender;
  double _mouthOpen = 0; // 0..1, driven by TTS word boundaries while speaking
  bool _speaking = false;
  Timer? _mouthCloseTimer;

  @override
  void initState() {
    super.initState();
    widget.controller?.attachNative(
      speak: _speak,
      onGenderChanged: (g) {
        if (mounted) setState(() => _gender = g);
      },
    );
    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      setState(() => _mouthOpen = word.length > 5 ? 1.0 : 0.55);
      _mouthCloseTimer?.cancel();
      _mouthCloseTimer = Timer(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _mouthOpen = 0.15);
      });
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _mouthOpen = 0;
      });
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _mouthOpen = 0;
      });
    });
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _speaking = true);
    await _tts.setPitch(_gender == 'male' ? 0.9 : 1.05);
    await _tts.speak(text);
  }

  @override
  void dispose() {
    widget.controller?.attachNative(speak: null, onGenderChanged: null);
    _mouthCloseTimer?.cancel();
    _tts.stop();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _idle,
        builder: (context, _) => CustomPaint(
          painter: _AvatarPainter(
            t: _idle.value,
            gender: _gender,
            mouthOpen: _mouthOpen,
            speaking: _speaking,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({
    required this.t,
    required this.gender,
    required this.mouthOpen,
    required this.speaking,
  });

  final double t;
  final String gender;
  final double mouthOpen;
  final bool speaking;

  static const _femaleSkin = Color(0xFFF4C9A0);
  static const _maleSkin = Color(0xFFE7B48C);
  static const _femaleHair = Color(0xFF3B2A22);
  static const _maleHair = Color(0xFF20262E);
  static const _femaleTop = Color(0xFF6C5CE7);
  static const _maleTop = Color(0xFF2563EB);

  @override
  void paint(Canvas canvas, Size size) {
    final isFemale = gender != 'male';
    final skin = isFemale ? _femaleSkin : _maleSkin;
    final hair = isFemale ? _femaleHair : _maleHair;
    final top = isFemale ? _femaleTop : _maleTop;

    final cx = size.width / 2;
    final sway = math.sin(t * 2 * math.pi) * 4;
    final bob = math.sin(t * 2 * math.pi * 2) * 2;
    final cy = size.height * 0.46 + bob;
    final headR = math.min(size.width, size.height) * 0.22;

    // shoulders / torso
    final shoulderY = cy + headR * 1.55;
    final torso = Path()
      ..moveTo(cx - headR * 2.1, size.height)
      ..quadraticBezierTo(cx - headR * 2.1, shoulderY, cx - headR * 1.1,
          shoulderY - headR * 0.35)
      ..quadraticBezierTo(cx, shoulderY - headR * 0.55, cx + headR * 1.1,
          shoulderY - headR * 0.35)
      ..quadraticBezierTo(
          cx + headR * 2.1, shoulderY, cx + headR * 2.1, size.height)
      ..close();
    canvas.drawPath(torso, Paint()..color = top);

    canvas.save();
    canvas.translate(cx + sway, cy);

    // neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, headR * 0.85),
              width: headR * 0.6,
              height: headR * 0.5),
          Radius.circular(headR * 0.15)),
      Paint()..color = skin,
    );

    // head
    canvas.drawCircle(Offset.zero, headR, Paint()..color = skin);

    // hair
    final hairPath = Path()
      ..addArc(
          Rect.fromCircle(center: Offset(0, -headR * 0.05), radius: headR * 1.04),
          math.pi,
          math.pi)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);
    if (isFemale) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(-headR * 0.95, headR * 0.25),
              width: headR * 0.5,
              height: headR * 1.1),
          Paint()..color = hair);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(headR * 0.95, headR * 0.25),
              width: headR * 0.5,
              height: headR * 1.1),
          Paint()..color = hair);
    }

    // eyes (blink)
    final blinkCycle = (t * 4) % 1.0;
    final blink = blinkCycle > 0.94 ? 0.1 : 1.0;
    final eyeW = headR * 0.22;
    final eyeH = headR * 0.16 * blink;
    for (final dx in [-headR * 0.38, headR * 0.38]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dx, -headR * 0.08), width: eyeW, height: eyeH),
        Paint()..color = const Color(0xFF2B2B2B),
      );
    }

    // eyebrows
    final brow = Paint()
      ..color = hair
      ..strokeWidth = headR * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-headR * 0.5, -headR * 0.28),
        Offset(-headR * 0.24, -headR * 0.32), brow);
    canvas.drawLine(Offset(headR * 0.24, -headR * 0.32),
        Offset(headR * 0.5, -headR * 0.28), brow);

    // mouth: closed line .. open oval, sized by mouthOpen
    final mouthY = headR * 0.42;
    final mw = headR * 0.34;
    final mh = (headR * 0.06) + (headR * 0.22 * mouthOpen);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, mouthY), width: mw, height: mh),
          Radius.circular(mh / 2)),
      Paint()..color = const Color(0xFF7A3B3B),
    );
    if (mouthOpen > 0.35) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, mouthY - mh * 0.18),
                width: mw * 0.86,
                height: mh * 0.32),
            Radius.circular(mh * 0.16)),
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }

    // cheeks
    for (final dx in [-headR * 0.6, headR * 0.6]) {
      canvas.drawCircle(Offset(dx, headR * 0.18), headR * 0.13,
          Paint()..color = const Color(0xFFFF9E9E).withOpacity(0.22));
    }

    // speaking glow ring
    if (speaking) {
      canvas.drawCircle(
        Offset.zero,
        headR * 1.18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = top.withOpacity(
              0.35 + 0.25 * math.sin(t * 2 * math.pi * 3).abs()),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.t != t ||
      old.gender != gender ||
      old.mouthOpen != mouthOpen ||
      old.speaking != speaking;
}
