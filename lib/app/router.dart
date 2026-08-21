import 'package:flutter/material.dart';
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

/// 달력 페이지. **키를 달 단위로 준다.**
///
/// `/2026/08` ↔ `/2026/08/15`처럼 같은 달 안에서 오가면 키가 같아 Navigator가
/// 새 화면을 띄우지 않고 **같은 페이지를 그 자리에서 다시 빌드**한다(전환 애니메이션도
/// 없다). 선택 날짜는 `CalendarPage.didUpdateWidget`이 받아 적용한다.
///
/// 다른 달로 가면 키가 달라져 정상적으로 새 페이지가 되고, 그때는 `initState`가
/// `initialSelected`를 적용한다.
MaterialPage<void> _calendarPage(YearMonth ym, CalendarPage child) =>
    MaterialPage<void>(
      key: ValueKey('calendar-${ym.year}-${ym.month}'),
      child: child,
    );

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
      // `:day`는 `/:year/:month`의 **자식이 아니라 형제**다. 자식으로 두면
      // `/2026/08` → `/2026/08/15` 이동이 달력 페이지를 하나 더 쌓아서, 위젯에서
      // 날짜를 누르면 새 달력 화면이 열린 것처럼 보였다.
      GoRoute(
        name: 'month',
        path: '/:year/:month',
        pageBuilder: (context, state) {
          final ym = _parseMonth(state);
          return _calendarPage(ym, CalendarPage(month: ym));
        },
      ),
      GoRoute(
        name: 'day',
        path: '/:year/:month/:day',
        pageBuilder: (context, state) {
          final ym = _parseMonth(state);
          final day = (int.tryParse(state.pathParameters['day'] ?? '') ?? 1)
              .clamp(1, ym.daysInMonth);
          return _calendarPage(
            ym,
            CalendarPage(
              month: ym,
              initialSelected: DateTime(ym.year, ym.month, day),
            ),
          );
        },
      ),
    ],
  );
}
