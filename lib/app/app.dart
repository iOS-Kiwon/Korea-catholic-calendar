import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_update/app_update_service.dart';
import '../features/ads/ads.dart';
import '../features/events/application/category_providers.dart';
import '../features/events/application/event_providers.dart';
import '../features/calendar/application/calendar_providers.dart';
import '../features/widgets/widget_snapshot_service.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CatholicCalendarApp extends ConsumerStatefulWidget {
  const CatholicCalendarApp({super.key});

  @override
  ConsumerState<CatholicCalendarApp> createState() =>
      _CatholicCalendarAppState();
}

class _CatholicCalendarAppState extends ConsumerState<CatholicCalendarApp> {
  final _rootNavigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router = buildRouter(
    navigatorKey: _rootNavigatorKey,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
  );
  final _widgetSnapshotService = const WidgetSnapshotService();

  @override
  void initState() {
    super.initState();
    if (adsEnabled) {
      // Consent → ATT → Mobile Ads SDK, after the first frame (no-op off mobile).
      WidgetsBinding.instance.addPostFrameCallback((_) => initAds());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(personalCloudBackupControllerProvider).restoreIfAvailable().then(
        (restored) {
          if (!mounted || !restored) return;
          ref.invalidate(categoriesProvider);
        },
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAppUpdate());
  }

  Future<void> _checkAppUpdate() async {
    final policy = await const AppUpdateService().check();
    if (!mounted || policy == null) return;

    final dialogContext = _rootNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: !policy.isForceUpdate,
      builder: (context) => PopScope(
        canPop: !policy.isForceUpdate,
        child: AlertDialog(
          title: Text(policy.title),
          content: policy.message.isEmpty ? null : Text(policy.message),
          actions: [
            if (policy.isRecommendedUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('다음에'),
              ),
            FilledButton(
              onPressed: () => AppUpdateService.openStore(),
              child: const Text('업데이트'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncWidgetSnapshot() {
    final calendar = ref.read(calendarControllerProvider).value;
    final events = ref.read(eventStoreProvider).value;
    if (calendar == null || events == null) return;
    _widgetSnapshotService.sync(calendar: calendar, events: events);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(calendarControllerProvider, (_, _) => _syncWidgetSnapshot());
    ref.listen(eventStoreProvider, (_, _) => _syncWidgetSnapshot());

    return MaterialApp.router(
      title: '가톨릭 달력',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light, // 다크 모드 미지원 — 항상 라이트 테마
      routerConfig: _router,
      // 배너 광고는 화면 하단(SafeArea.bottom 바로 위)에 항상 고정한다.
      // 키보드가 뜨면 각 화면이 키보드 높이만큼 인셋을 잡는데, 그 아래에 광고가
      // 있어 광고 높이만큼 이중으로 밀려 공백이 생긴다. 그래서 자식에게 전달하는
      // 하단 인셋을 광고 높이만큼 줄여 공백을 없앤다(광고는 그대로 하단 고정).
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!adsEnabled) return content;
        return Column(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  // 광고 배너는 하단에 '배너 높이 + 세이프영역'만큼 고정되어 있으므로
                  // (maintainBottomViewPadding), 자식의 키보드 인셋을 그만큼 줄여야
                  // 버튼과 키보드 사이에 공백이 생기지 않는다.
                  final adReserved = bottomAdBannerHeight + media.viewPadding.bottom;
                  final reduced = (media.viewInsets.bottom - adReserved)
                      .clamp(0.0, double.infinity);
                  return MediaQuery(
                    data: media.copyWith(
                      viewInsets: EdgeInsets.fromLTRB(
                        media.viewInsets.left,
                        media.viewInsets.top,
                        media.viewInsets.right,
                        reduced,
                      ),
                    ),
                    child: content,
                  );
                },
              ),
            ),
            const BottomAdBanner(),
          ],
        );
      },
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
