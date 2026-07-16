import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';

/// A small dot representing a liturgical color, optionally with its Korean
/// label. Color is never the only signal — the label carries the meaning.
class LiturgicalColorBadge extends StatelessWidget {
  const LiturgicalColorBadge(
    this.color, {
    super.key,
    this.showLabel = false,
    this.size = 12,
  });

  final LiturgicalColor color;
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.liturgical.of(color),
        shape: BoxShape.circle,
      ),
    );
    if (!showLabel) return dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(LiturgicalColors.label(color)),
      ],
    );
  }
}
