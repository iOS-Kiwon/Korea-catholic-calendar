import 'package:flutter/material.dart';

import 'liturgical_colors.dart';

/// Light and dark [ThemeData] for the app, each carrying the [LiturgicalColors]
/// theme extension. The "modern eclectic" look: a soft neutral page behind a
/// crisp white (or dark) rounded calendar card.
class AppTheme {
  static const _pageLight = Color(0xFFEDEBE4); // warm beige page background
  static const _pageDark = Color(0xFF15130F);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _pageLight,
      extensions: const [LiturgicalColors.light],
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _pageDark,
      extensions: const [LiturgicalColors.dark],
    );
  }
}
