import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/date/year_month.dart';
import '../features/calendar/presentation/pages/calendar_page.dart';

/// Parses and clamps the `:year`/`:month` path parameters into a [YearMonth],
/// falling back to the current month when they are missing or invalid.
YearMonth _parseMonth(GoRouterState state) {
  final now = DateTime.now();
  final year = int.tryParse(state.pathParameters['year'] ?? '') ?? now.year;
  final month = int.tryParse(state.pathParameters['month'] ?? '') ?? now.month;
  return YearMonth(year, month.clamp(1, 12));
}

GoRouter buildRouter({
  GlobalKey<NavigatorState>? navigatorKey,
  List<NavigatorObserver> observers = const [],
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    observers: observers,
    initialLocation: monthPath(YearMonth.of(DateTime.now())),
    routes: [
      GoRoute(
        name: 'home',
        path: '/',
        redirect: (context, state) => monthPath(YearMonth.of(DateTime.now())),
      ),
      GoRoute(
        name: 'month',
        path: '/:year/:month',
        builder: (context, state) => CalendarPage(month: _parseMonth(state)),
        routes: [
          GoRoute(
            name: 'day',
            path: ':day',
            builder: (context, state) {
              final ym = _parseMonth(state);
              final day = (int.tryParse(state.pathParameters['day'] ?? '') ?? 1)
                  .clamp(1, ym.daysInMonth);
              return CalendarPage(
                month: ym,
                initialSelected: DateTime(ym.year, ym.month, day),
              );
            },
          ),
        ],
      ),
    ],
  );
}
