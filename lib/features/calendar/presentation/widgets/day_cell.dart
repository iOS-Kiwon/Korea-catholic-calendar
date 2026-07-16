import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../season_style.dart';

const _todayFill = Color(0xFF121212); // 오늘: 검정 원
const _selectedFill = Color(0xFFD6D6D6); // 선택: 회색 원

Color _numberColor(BuildContext c, DateTime d, bool inMonth) {
  final theme = Theme.of(c);
  if (!inMonth) return theme.disabledColor;
  if (d.weekday == DateTime.sunday) return const Color(0xFFC62828);
  if (d.weekday == DateTime.saturday) return const Color(0xFF1565C0);
  return theme.colorScheme.onSurface;
}

/// 날짜 숫자. 오늘/선택일 때만 원형 배경을 채운다.
class DayNumber extends StatelessWidget {
  const DayNumber({
    super.key,
    required this.date,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    this.size = 34,
  });

  final DateTime date;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isToday
        ? _todayFill
        : (isSelected ? _selectedFill : Colors.transparent);
    final fg = isToday
        ? Colors.white
        : _numberColor(context, date, inCurrentMonth);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '${date.day}',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: fg,
          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}

/// A small marker shown on days that have a personal event, distinct from the
/// liturgical color dots (app-primary, at the number's top-right corner).
class EventDot extends StatelessWidget {
  const EventDot({super.key, this.size = 7});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary,
        border: Border.all(color: theme.colorScheme.surface, width: 1),
      ),
    );
  }
}

/// Wide (desktop/web) day cell: colored top bar + date circle + celebration name.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.hasEvent = false,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasEvent;

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
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 3, color: notable ? accent : Colors.transparent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DayNumber(
                          date: day.date,
                          inCurrentMonth: inCurrentMonth,
                          isToday: isToday,
                          isSelected: isSelected,
                          size: 28,
                        ),
                        if (hasEvent)
                          const Positioned(right: 0, top: 0, child: EventDot()),
                      ],
                    ),
                    if (notable) ...[
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          day.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
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

/// Compact (phone) day cell: date circle + a small liturgical-color dot below.
class CompactDayCell extends StatelessWidget {
  const CompactDayCell({
    super.key,
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.hasEvent = false,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasEvent;

  @override
  Widget build(BuildContext context) {
    final notable = inCurrentMonth && isNotableDay(day);
    final accent = context.liturgical.of(day.color);

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DayNumber(
                date: day.date,
                inCurrentMonth: inCurrentMonth,
                isToday: isToday,
                isSelected: isSelected,
              ),
              if (hasEvent)
                const Positioned(right: 0, top: 0, child: EventDot()),
            ],
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
