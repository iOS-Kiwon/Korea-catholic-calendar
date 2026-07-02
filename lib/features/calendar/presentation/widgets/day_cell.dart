import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../season_style.dart';

Color _numberColor(BuildContext c, DateTime d, bool inMonth) {
  final theme = Theme.of(c);
  if (!inMonth) return theme.disabledColor;
  if (d.weekday == DateTime.sunday) return const Color(0xFFC62828);
  if (d.weekday == DateTime.saturday) return const Color(0xFF1565C0);
  return theme.colorScheme.onSurface;
}

/// Wide (desktop/tablet) day cell: a colored top bar + date + celebration name,
/// with an "오늘" pill for today. Plain ferials show only the number.
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
    final notable = inCurrentMonth && isNotableDay(day);
    final accent = context.liturgical.of(day.color);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.25),
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 3, color: notable ? accent : Colors.transparent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${day.date.day}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _numberColor(
                              context,
                              day.date,
                              inCurrentMonth,
                            ),
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          _TodayPill(color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    if (notable) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          day.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '오늘',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Compact (phone) day cell: date number with a small liturgical-color dot;
/// today is a filled circle, the selected day an outlined ring.
class CompactDayCell extends StatelessWidget {
  const CompactDayCell({
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
    final notable = inCurrentMonth && isNotableDay(day);
    final accent = context.liturgical.of(day.color);

    final numColor = isToday
        ? Colors.white
        : _numberColor(context, day.date, inCurrentMonth);

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? theme.colorScheme.primary : null,
              border: (isSelected && !isToday)
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: numColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notable ? accent : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
