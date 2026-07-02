import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';

/// A single day cell: date number, a liturgical-color side bar, and the day's
/// celebration title. Adjacent-month days are muted; today and the selected day
/// carry decoration overlays.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.liturgical.of(day.color);
    final isSunday = day.date.weekday == DateTime.sunday;

    final dateColor = !inCurrentMonth
        ? theme.disabledColor
        : isSunday
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: inCurrentMonth ? 1 : 0.4,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isToday
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(7),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.date.day}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: dateColor,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          day.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
