import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../season_style.dart';

const _todayFill = Color(0xFF121212); // 오늘: 검정 원
const _selectedFill = Color(0xFFD6D6D6); // 선택: 회색 원

Color _numberColor(
  BuildContext c,
  DateTime d,
  bool inMonth,
  bool isKoreanHoliday,
  LiturgicalColor liturgicalColor,
) {
  final theme = Theme.of(c);
  if (!inMonth) return theme.disabledColor;
  if (isKoreanHoliday) return const Color(0xFFC62828);
  if (d.weekday == DateTime.sunday) return const Color(0xFFC62828);
  if (d.weekday == DateTime.saturday) return const Color(0xFF1565C0);
  if (liturgicalColor == LiturgicalColor.white) {
    // 백색 전례일은 순검정보다 그리드 배경을 조금 섞어 차콜 톤으로 낮춘다.
    return Color.lerp(
      theme.colorScheme.onSurface,
      theme.scaffoldBackgroundColor,
      0.16,
    )!;
  }
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
    required this.liturgicalColor,
    this.isKoreanHoliday = false,
    this.isKoreanHolidayTitle = false,
    this.size = 34,
  });

  final DateTime date;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final LiturgicalColor liturgicalColor;
  final bool isKoreanHoliday;
  final bool isKoreanHolidayTitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge;
    final bg = isToday
        ? _todayFill
        : (isSelected ? _selectedFill : Colors.transparent);
    final fg = isToday
        ? Colors.white
        : _numberColor(
            context,
            date,
            inCurrentMonth,
            isKoreanHoliday,
            liturgicalColor,
          );
    final circleSize = isToday || isSelected ? size - 4 : size;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: circleSize,
          height: circleSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text(
            '${date.day}',
            style: baseStyle?.copyWith(
              color: fg,
              // Keep the date cell footprint unchanged while making the
              // highlighted circle easier to separate from the title below.
              fontSize: (baseStyle.fontSize ?? 16) + 2,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            ),
          ),
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
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 1),
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
    this.isKoreanHoliday = false,
    this.isKoreanHolidayTitle = false,
    required this.onTap,
    this.hasEvent = false,
    this.shortTitle,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isKoreanHoliday;
  final bool isKoreanHolidayTitle;
  final VoidCallback onTap;
  final bool hasEvent;
  final String? shortTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.labelMedium ?? const TextStyle();
    final notable = inCurrentMonth && isNotableDay(day);
    final accent = context.liturgical.of(day.color);
    final hasTitle = shortTitle?.trim().isNotEmpty == true;
    final titleAccent = isKoreanHolidayTitle ? const Color(0xFFC62828) : accent;
    final isWhiteTitle =
        day.color == LiturgicalColor.white && !isKoreanHolidayTitle;

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          // Keep the grid visually continuous with the phone layout. The
          // footer/card surface is intentionally a different, softer white.
          color: theme.scaffoldBackgroundColor,
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              color: notable || hasTitle ? titleAccent : Colors.transparent,
            ),
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
                          liturgicalColor: day.color,
                          isKoreanHoliday: isKoreanHoliday,
                          size: 28,
                        ),
                        if (hasEvent)
                          const Positioned(right: 0, top: 0, child: EventDot()),
                      ],
                    ),
                    if (shortTitle case final title?) ...[
                      const SizedBox(height: 1),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle.copyWith(
                            color: isKoreanHolidayTitle
                                ? const Color(0xFFC62828)
                                : isWhiteTitle
                                ? Colors.black
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: (titleStyle.fontSize ?? 12) + 2,
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

/// Compact (phone) day cell: date circle + optional personal-event marker.
class CompactDayCell extends StatelessWidget {
  const CompactDayCell({
    super.key,
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    this.isKoreanHoliday = false,
    this.isKoreanHolidayTitle = false,
    this.onTap,
    this.hasEvent = false,
    this.shortTitle,
    this.titleMaxLines = 3,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isKoreanHoliday;
  final bool isKoreanHolidayTitle;
  final VoidCallback? onTap;
  final bool hasEvent;
  final String? shortTitle;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWhiteTitle =
        day.color == LiturgicalColor.white && !isKoreanHolidayTitle;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DayNumber(
                date: day.date,
                inCurrentMonth: inCurrentMonth,
                isToday: isToday,
                isSelected: isSelected,
                liturgicalColor: day.color,
                isKoreanHoliday: isKoreanHoliday,
              ),
              if (hasEvent)
                const Positioned(right: 0, top: 0, child: EventDot()),
            ],
          ),
          if (shortTitle case final title?) ...[
            const SizedBox(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isKoreanHolidayTitle
                        ? const Color(0xFFC62828)
                        : isWhiteTitle
                        ? Colors.black
                        : context.liturgical.of(day.color),
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
