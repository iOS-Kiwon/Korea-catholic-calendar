import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date/year_month.dart';
import '../../../events/application/event_providers.dart';
import '../../application/liturgical_display_filter.dart';
import '../../data/calendar_service.dart';
import 'day_cell.dart';

const _compactTwoLineTitleMinRowHeight = 56.0;

/// A monthly grid. Weeks start on Sunday; adjacent-month days are shown muted.
/// [compact] switches between the phone cells and the wide (named) cells.
class MonthGrid extends ConsumerWidget {
  const MonthGrid({
    super.key,
    required this.calendar,
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.onSelectDay,
    this.compact = false,
  });

  final CalendarService calendar;
  final YearMonth month;
  final DateTime today;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDay;
  final bool compact;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7; // Sunday = 0
    final rows = (leading + month.daysInMonth + 6) ~/ 7;
    final start = DateTime(month.year, month.month, 1 - leading);
    final filter = ref.watch(liturgicalDisplayFilterProvider);

    Widget cellAt(int r, int c, {required int compactTitleMaxLines}) {
      final date = DateTime(start.year, start.month, start.day + r * 7 + c);
      final day = calendar.day(date);
      final inMonth = date.month == month.month;
      final isToday = _sameDay(date, today);
      final isSelected = selectedDate != null && _sameDay(date, selectedDate!);
      final hasEvent = ref.watch(dayHasEventProvider(date));
      final shortTitle = inMonth
          ? gridLiturgicalLabel(filter, calendar.shortTitleFor(day), day)
          : null;
      return compact
          ? CompactDayCell(
              day: day,
              shortTitle: shortTitle,
              inCurrentMonth: inMonth,
              isToday: isToday,
              isSelected: isSelected,
              hasEvent: hasEvent,
              titleMaxLines: compactTitleMaxLines,
              onTap: () => onSelectDay(date),
            )
          : DayCell(
              day: day,
              shortTitle: shortTitle,
              inCurrentMonth: inMonth,
              isToday: isToday,
              isSelected: isSelected,
              hasEvent: hasEvent,
              onTap: () => onSelectDay(date),
            );
    }

    Widget rowAt(int r, {required int compactTitleMaxLines}) => Row(
      children: [
        for (var c = 0; c < 7; c++)
          Expanded(
            child: cellAt(r, c, compactTitleMaxLines: compactTitleMaxLines),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultRowHeight = compact ? 58.0 : 92.0;
        final rowHeight = constraints.maxHeight.isFinite
            ? compact
                  ? math.min(defaultRowHeight, constraints.maxHeight / rows)
                  : constraints.maxHeight / rows
            : defaultRowHeight;
        final compactTitleMaxLines =
            compact && rowHeight >= _compactTwoLineTitleMinRowHeight ? 2 : 1;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (var r = 0; r < rows; r++)
              SizedBox(
                height: rowHeight,
                child: rowAt(r, compactTitleMaxLines: compactTitleMaxLines),
              ),
          ],
        );
      },
    );
  }
}
