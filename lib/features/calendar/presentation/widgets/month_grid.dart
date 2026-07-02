import 'package:flutter/material.dart';

import '../../../../core/date/year_month.dart';
import '../../data/calendar_service.dart';
import 'day_cell.dart';

/// A monthly grid of [DayCell]s. Weeks start on Sunday; leading/trailing days
/// from adjacent months are shown muted. Each cell's liturgical data is
/// resolved from [calendar], so adjacent-month days render correctly too.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.calendar,
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.onSelectDay,
  });

  final CalendarService calendar;
  final YearMonth month;
  final DateTime today;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDay;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7; // Sunday = 0
    final rows = ((leading + month.daysInMonth + 6) ~/ 7);
    final start = DateTime(month.year, month.month, 1 - leading);

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Builder(
                    builder: (context) {
                      final date = DateTime(
                        start.year,
                        start.month,
                        start.day + r * 7 + c,
                      );
                      final day = calendar.day(date);
                      return Expanded(
                        child: DayCell(
                          day: day,
                          inCurrentMonth: date.month == month.month,
                          isToday: _sameDay(date, today),
                          isSelected:
                              selectedDate != null &&
                              _sameDay(date, selectedDate!),
                          onTap: () => onSelectDay(date),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
