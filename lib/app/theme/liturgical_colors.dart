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

  final Color white; // 백색
  final Color red; // 홍색
  final Color green; // 녹색
  final Color violet; // 자색
  final Color rose; // 장미색
  final Color black; // 흑색

  static const dark = LiturgicalColors(
    white: Color(0xFFFFFFFF),
    red: Color(0xFFE53935),
    green: Color(0xFF43A047),
    violet: Color(0xFF8E5AD7),
    rose: Color(0xFFF06292),
    black: Color(0xFF000000),
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
