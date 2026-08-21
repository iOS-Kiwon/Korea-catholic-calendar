import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date/year_month.dart';
import '../../../events/application/event_providers.dart';
import '../../application/liturgical_display_filter.dart';
import '../../data/calendar_service.dart';
import 'day_cell.dart';

// 아래 두 임계값과 `compactTitleMaxLines`는 줄 수의 **상한**이다. 폰트 배율이
// 커지면 셀이(`_CellTitle`) 남은 높이를 실제로 재서 이 값보다 더 줄인다.
// 예전에는 이 임계값이 유일한 결정자였고 배율 1.0을 전제했기 때문에, OS 글꼴을
// 키우면 3줄을 그대로 유지한 채 3번째 줄이 세로로 잘렸다.
const _compactThreeLineTitleMinRowHeight = 70.0;
const _compactTwoLineTitleMinRowHeight = 59.0;

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
    this.fixedRowHeight,
  });

  final CalendarService calendar;
  final YearMonth month;
  final DateTime today;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDay;
  final bool compact;

  /// When set, every rendered week uses this height instead of deriving it
  /// from the parent's available height.
  final double? fixedRowHeight;

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
      final isKoreanHoliday = calendar.isKoreanHoliday(date);
      final hasEvent = ref.watch(dayHasEventProvider(date));
      final shortTitle = inMonth
          ? gridLiturgicalLabel(filter, calendar.shortTitleFor(day), day)
          : null;
      final holidayTitle = inMonth
          ? calendar.koreanHolidayTitleFor(date)
          : null;
      final isKoreanHolidayTitle =
          shortTitle?.trim().isNotEmpty != true && holidayTitle != null;
      final title = shortTitle?.trim().isNotEmpty == true
          ? shortTitle
          : holidayTitle;
      return compact
          ? CompactDayCell(
              day: day,
              shortTitle: title,
              inCurrentMonth: inMonth,
              isToday: isToday,
              isSelected: isSelected,
              isKoreanHoliday: isKoreanHoliday,
              isKoreanHolidayTitle: isKoreanHolidayTitle,
              hasEvent: hasEvent,
              titleMaxLines: compactTitleMaxLines,
              onTap: () => onSelectDay(date),
            )
          : DayCell(
              day: day,
              shortTitle: title,
              inCurrentMonth: inMonth,
              isToday: isToday,
              isSelected: isSelected,
              isKoreanHoliday: isKoreanHoliday,
              isKoreanHolidayTitle: isKoreanHolidayTitle,
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
        // A 3-line title needs a little more room below the unchanged date
        // circle. The grid is already inside an Expanded area on phones, so
        // this does not change the overall calendar screen height.
        final defaultRowHeight = compact ? 72.0 : 92.0;
        final rowHeight =
            fixedRowHeight ??
            (constraints.maxHeight.isFinite
                ? compact
                      ? math.min(defaultRowHeight, constraints.maxHeight / rows)
                      : constraints.maxHeight / rows
                : defaultRowHeight);
        final compactTitleMaxLines = !compact
            ? 1
            : rowHeight >= _compactThreeLineTitleMinRowHeight
            ? 3
            : rowHeight >= _compactTwoLineTitleMinRowHeight
            ? 2
            : 1;

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
