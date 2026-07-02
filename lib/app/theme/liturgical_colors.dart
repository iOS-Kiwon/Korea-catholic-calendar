import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

/// Semantic liturgical-color tokens, tuned per brightness for legibility.
///
/// These are domain colors (전례색), not brand colors, so they live in a
/// [ThemeExtension] rather than in [ColorScheme]. Color is never the sole
/// signal in the UI — it always accompanies text — but the tokens are still
/// chosen to be distinguishable and to render on both light and dark surfaces.
@immutable
class LiturgicalColors extends ThemeExtension<LiturgicalColors> {
  const LiturgicalColors({
    required this.white,
    required this.red,
    required this.green,
    required this.violet,
    required this.rose,
    required this.black,
  });

  final Color white; // 백색 (gold-tinted so it is visible)
  final Color red; // 홍색
  final Color green; // 녹색
  final Color violet; // 자색
  final Color rose; // 장미색
  final Color black; // 흑색

  static const light = LiturgicalColors(
    white: Color(0xFFB59410),
    red: Color(0xFFC62828),
    green: Color(0xFF2E7D32),
    violet: Color(0xFF6A1B9A),
    rose: Color(0xFFD81B60),
    black: Color(0xFF455A64),
  );

  static const dark = LiturgicalColors(
    white: Color(0xFFD9BE5C),
    red: Color(0xFFEF7A7A),
    green: Color(0xFF7CC47F),
    violet: Color(0xFFC58AE0),
    rose: Color(0xFFF48FB1),
    black: Color(0xFFB0BEC5),
  );

  Color of(LiturgicalColor c) {
    switch (c) {
      case LiturgicalColor.white:
        return white;
      case LiturgicalColor.red:
        return red;
      case LiturgicalColor.green:
        return green;
      case LiturgicalColor.violet:
        return violet;
      case LiturgicalColor.rose:
        return rose;
      case LiturgicalColor.black:
        return black;
    }
  }

  /// Korean label for a liturgical color.
  static String label(LiturgicalColor c) {
    switch (c) {
      case LiturgicalColor.white:
        return '백색';
      case LiturgicalColor.red:
        return '홍색';
      case LiturgicalColor.green:
        return '녹색';
      case LiturgicalColor.violet:
        return '자색';
      case LiturgicalColor.rose:
        return '장미색';
      case LiturgicalColor.black:
        return '흑색';
    }
  }

  @override
  LiturgicalColors copyWith({
    Color? white,
    Color? red,
    Color? green,
    Color? violet,
    Color? rose,
    Color? black,
  }) {
    return LiturgicalColors(
      white: white ?? this.white,
      red: red ?? this.red,
      green: green ?? this.green,
      violet: violet ?? this.violet,
      rose: rose ?? this.rose,
      black: black ?? this.black,
    );
  }

  @override
  LiturgicalColors lerp(ThemeExtension<LiturgicalColors>? other, double t) {
    if (other is! LiturgicalColors) return this;
    return LiturgicalColors(
      white: Color.lerp(white, other.white, t)!,
      red: Color.lerp(red, other.red, t)!,
      green: Color.lerp(green, other.green, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      black: Color.lerp(black, other.black, t)!,
    );
  }
}

/// Convenience accessor for the liturgical color palette from a [BuildContext].
extension LiturgicalColorsContext on BuildContext {
  LiturgicalColors get liturgical =>
      Theme.of(this).extension<LiturgicalColors>()!;
}
