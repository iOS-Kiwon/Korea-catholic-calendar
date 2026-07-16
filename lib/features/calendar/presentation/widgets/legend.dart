import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';

/// The four liturgical-color categories shown as a legend on wide layouts.
class Legend extends StatelessWidget {
  const Legend({super.key});

  static const _items = <(String, LiturgicalColor)>[
    ('연중', LiturgicalColor.green),
    ('축일·성인', LiturgicalColor.white),
    ('사도·순교', LiturgicalColor.red),
    ('사순·대림', LiturgicalColor.violet),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        for (final (label, color) in _items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: context.liturgical.of(color),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
      ],
    );
  }
}
