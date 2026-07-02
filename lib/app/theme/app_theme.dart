import 'package:flutter/material.dart';

import 'liturgical_colors.dart';

/// Light and dark [ThemeData] for the app, each carrying the [LiturgicalColors]
/// theme extension.
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6A1B9A),
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: const [LiturgicalColors.light],
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6A1B9A),
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: const [LiturgicalColors.dark],
    );
  }
}
