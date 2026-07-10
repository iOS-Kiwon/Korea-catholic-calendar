import 'package:flutter/material.dart';

import '../../../../core/date/year_month.dart';
import '../../data/calendar_service.dart';
import 'day_cell.dart';

/// A monthly grid. Weeks start on Sunday; adjacent-month days are shown muted.
/// [compact] switches between the phone (dot) cells and the wide (named) cells.
class MonthGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7; // Sunday = 0
    final rows = (leading + month.daysInMonth + 6) ~/ 7;
    final start = DateTime(month.year, month.month, 1 - leading);

    Widget cellAt(int r, int c) {
      final date = DateTime(start.year, start.month, start.day + r * 7 + c);
      final day = calendar.day(date);
      final inMonth = date.month == month.month;
      final isToday = _sameDay(date, today);
      final isSelected = selectedDate != null && _sameDay(date, selectedDate!);
      return compact
          ? CompactDayCell(
              day: day,
              inCurrentMonth: inMonth,
              isToday: isToday,
              isSelected: isSelected,
              onTap: () => onSelectDay(date),
            )
          : DayCell(
              day: day,
              inCurrentMonth: inMonth,
              isToday: isToday,
              isSelected: isSelected,
              onTap: () => onSelectDay(date),
            );
    }

    Widget rowAt(int r) => Row(
      children: [for (var c = 0; c < 7; c++) Expanded(child: cellAt(r, c))],
    );

    // 두 레이아웃 모두 행을 균등하게 채운다(부모 높이에 맞춰 늘어남 → 오버플로 방지).
    return Column(
      children: [for (var r = 0; r < rows; r++) Expanded(child: rowAt(r))],
    );
  }
}
