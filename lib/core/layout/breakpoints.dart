import 'package:flutter/widgets.dart';

/// Logical form factors driven by available width.
enum WindowSize {
  compact, // < 600  — phone: single month, detail as a pushed route
  medium, // 600–1024 — detail as a bottom sheet
  expanded; // > 1024 — master-detail with a persistent side pane

  static WindowSize fromWidth(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 1024) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isExpanded => this == WindowSize.expanded;
  bool get isCompact => this == WindowSize.compact;
}

/// Resolves the [WindowSize] from the given constraints.
WindowSize windowSizeOf(BoxConstraints constraints) =>
    WindowSize.fromWidth(constraints.maxWidth);
