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
    // 공유 딥링크(예: https://kcc.sidore.org/e/...)로 앱이 열리면 iOS/Android가
    // 그 원본 URL을 go_router의 초기 위치로 그대로 넘기는데, 이는 우리 라우트
    // 패턴과 맞지 않아 기본 "Page Not Found" 화면이 뜬다. 이 초기 진입 시점의
    // 불일치는 앱 내부(app.dart의 app_links 처리)가 곧 올바른 날짜로 다시
    // 이동시켜 주므로, 여기서는 에러 화면 대신 현재 달 화면으로 조용히 대체한다.
    errorBuilder: (context, state) =>
        CalendarPage(month: YearMonth.of(DateTime.now())),
    routes: [
      GoRoute(
        name: 'home',
        path: '/',
        redirect: (context, state) => monthPath(YearMonth.of(DateTime.now())),
      ),
      // 메인 달력의 월 이동은 무전환으로 고정한다. 좌우 제스처에서 월 화면이
      // 새 페이지처럼 밀려 들어오는 애니메이션이 발생하지 않아야 한다.
      GoRoute(
        name: 'month',
        path: '/:year/:month',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: CalendarPage(month: _parseMonth(state)),
        ),
      ),
      // 위젯의 날짜 딥링크도 같은 무전환 정책을 사용해, 앱 진입 및 진입 직후
      // 제스처에서 라우트 종류가 바뀌어도 애니메이션이 생기지 않게 한다.
      GoRoute(
        name: 'day',
        path: '/:year/:month/:day',
        pageBuilder: (context, state) {
          final ym = _parseMonth(state);
          final day = (int.tryParse(state.pathParameters['day'] ?? '') ?? 1)
              .clamp(1, ym.daysInMonth);
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: CalendarPage(
              month: ym,
              initialSelected: DateTime(ym.year, ym.month, day),
            ),
          );
        },
      ),
    ],
  );
}
