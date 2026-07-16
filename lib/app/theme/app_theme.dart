import 'package:flutter/material.dart';

import 'liturgical_colors.dart';

/// Dark [ThemeData] for the app, carrying the [LiturgicalColors] theme
/// extension. The black surface lets the white liturgical color render as
/// actual white instead of a gold-tinted substitute.
class AppTheme {
  static const _pageDark = Color(0xFF000000);
  static const _surfaceDark = Color(0xFF0B0B0B);
  static const _surfaceContainerDark = Color(0xFF171717);

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ).copyWith(
          surface: _surfaceDark,
          surfaceContainerLowest: _pageDark,
          surfaceContainerLow: _surfaceDark,
          surfaceContainer: _surfaceContainerDark,
          surfaceContainerHigh: const Color(0xFF202020),
          surfaceContainerHighest: const Color(0xFF2A2A2A),
        );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: _pageDark,
      cardColor: _surfaceDark,
      canvasColor: _pageDark,
      dialogTheme: const DialogThemeData(backgroundColor: _surfaceDark),
      dividerColor: Colors.white24,
      extensions: const [LiturgicalColors.dark],
    );
  }
}
