import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/date/year_month.dart';
import '../features/calendar/presentation/pages/calendar_page.dart';
import '../features/calendar/presentation/pages/day_detail_page.dart';

/// Parses and clamps the `:year`/`:month` path parameters into a [YearMonth],
/// falling back to the current month when they are missing or invalid.
YearMonth _parseMonth(GoRouterState state) {
  final now = DateTime.now();
  final year = int.tryParse(state.pathParameters['year'] ?? '') ?? now.year;
  final month = int.tryParse(state.pathParameters['month'] ?? '') ?? now.month;
  final clampedMonth = month.clamp(1, 12);
  return YearMonth(year, clampedMonth);
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: monthPath(YearMonth.of(DateTime.now())),
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => monthPath(YearMonth.of(DateTime.now())),
      ),
      GoRoute(
        path: '/:year/:month',
        builder: (context, state) => CalendarPage(month: _parseMonth(state)),
        routes: [
          GoRoute(
            path: ':day',
            builder: (context, state) {
              final ym = _parseMonth(state);
              final day = (int.tryParse(state.pathParameters['day'] ?? '') ?? 1)
                  .clamp(1, ym.daysInMonth);
              final date = DateTime(ym.year, ym.month, day);
              final expanded = MediaQuery.sizeOf(context).width >= 1024;
              return expanded
                  ? CalendarPage(month: ym, selectedDate: date)
                  : DayDetailPage(date: date);
            },
          ),
        ],
      ),
    ],
  );
}
