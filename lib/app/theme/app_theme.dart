import 'package:flutter/material.dart';

import 'liturgical_colors.dart';

/// Light [ThemeData] for the app, carrying the [LiturgicalColors] theme
/// extension. The "modern eclectic" look: a soft neutral page behind a crisp
/// white rounded calendar card. Dark mode is intentionally not supported.
class AppTheme {
  static const _pageLight = Color(0xFFEDEBE4); // warm beige page background

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
}
