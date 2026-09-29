import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens for the "chalkboard" visual identity. Currently scoped to
/// the AI Teacher home screen (see ai_teacher_screen.dart) — not the app-wide
/// theme.
class ChalkColors {
  const ChalkColors._();

  /// Deep teal-green — the hero card's blob fill.
  static const chalkboard = Color(0xFF1F3A3D);

  /// Page background this screen's cards sit on.
  static const paper = Color(0xFFF6F5F1);

  /// Primary text color.
  static const ink = Color(0xFF1B1B1F);

  static const chalkYellow = Color(0xFFFFD166);
  static const chalkCoral = Color(0xFFFF6F59);
  static const chalkSky = Color(0xFF4EA8DE);
  static const chalkMint = Color(0xFF56C596);

  /// The four subject colors, cycled by list position so every subject gets
  /// one consistently reused everywhere it appears (its card, skill arc,
  /// chat-history tint, progress ring). Only 4 tones are defined but the app
  /// can have more than 4 subjects, hence the cycle.
  static const subjectPalette = [chalkSky, chalkMint, chalkCoral, chalkYellow];

  static Color forSubjectIndex(int index) =>
      subjectPalette[index % subjectPalette.length];

  /// Ink or white, whichever reads better on [background].
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.5 ? ink : Colors.white;
}

/// Type tokens: Baloo 2 for headings/display, Manrope for body/UI text.
class ChalkText {
  const ChalkText._();

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = ChalkColors.ink,
    double? height,
  }) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = ChalkColors.ink,
    double? height,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );
}
