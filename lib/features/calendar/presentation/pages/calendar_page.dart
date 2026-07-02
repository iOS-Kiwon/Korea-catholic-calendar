import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/date/year_month.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../application/calendar_providers.dart';
import '../../data/calendar_service.dart';
import '../widgets/day_detail_view.dart';
import '../widgets/month_grid.dart';
import '../widgets/month_header.dart';

String monthPath(YearMonth ym) =>
    '/${ym.year}/${ym.month.toString().padLeft(2, '0')}';

String dayPath(DateTime d) =>
    '/${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// The responsive calendar shell. On wide screens it shows a master-detail
/// layout (grid + persistent detail pane); on narrow screens the grid alone,
/// with day selection navigating to a detail route.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key, required this.month, this.selectedDate});

  final YearMonth month;
  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(liturgicalCalendarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('가톨릭 달력')),
      body: calendarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('전례력을 불러오지 못했습니다.\n$e')),
        data: (calendar) => LayoutBuilder(
          builder: (context, constraints) {
            final size = windowSizeOf(constraints);
            final grid = _buildGridArea(context, calendar);
            if (size.isExpanded) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: grid),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 2, child: _detailPane(context, calendar)),
                ],
              );
            }
            return grid;
          },
        ),
      ),
    );
  }

  Widget _buildGridArea(BuildContext context, CalendarService calendar) {
    final today = DateTime.now();
    return Column(
      children: [
        MonthHeader(
          month: month,
          onPrevious: () => context.go(monthPath(month.previous)),
          onNext: () => context.go(monthPath(month.next)),
          onToday: () => context.go(monthPath(YearMonth.of(today))),
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -200) context.go(monthPath(month.next));
              if (v > 200) context.go(monthPath(month.previous));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MonthGrid(
                calendar: calendar,
                month: month,
                today: today,
                selectedDate: selectedDate,
                onSelectDay: (date) => context.go(dayPath(date)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailPane(BuildContext context, CalendarService calendar) {
    final date = selectedDate ?? DateTime.now();
    if (selectedDate == null &&
        (date.year != month.year || date.month != month.month)) {
      // No selection and "today" is not in the visible month: prompt.
      return const Center(child: Text('날짜를 선택하세요'));
    }
    return DayDetailView(day: calendar.day(date));
  }
}
