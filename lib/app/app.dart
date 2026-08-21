import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/date/year_month.dart';
import '../features/app_update/app_update_service.dart';
import '../features/ads/ads.dart';
import '../features/app_metadata/app_metadata_service.dart';
import '../features/calendar/presentation/pages/calendar_page.dart';
import '../features/events/application/event_providers.dart';
import '../features/events/model/calendar_event.dart';
import '../features/events/presentation/backup_notice.dart';
import '../features/events/presentation/backup_reminder.dart';
import '../features/events/presentation/event_editor_sheet.dart';
import '../features/sharing/share_link.dart';
import '../features/widgets/widget_snapshot_service.dart';
import '../features/calendar/application/calendar_providers.dart';
import '../features/widgets/widget_sync_throttle.dart';
import 'router.dart';
import 'theme/app_theme.dart';

// Optional layout-only viewport override for narrow-device QA. This is off by
// default and is enabled with --dart-define=KCC_FORCE_LAYOUT_WIDTH=320.
const _forcedLayoutWidth = int.fromEnvironment(
  'KCC_FORCE_LAYOUT_WIDTH',
  defaultValue: 0,
);

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
  final _appLinks = AppLinks();

  /// 일정·축일이 바뀐 그 순간 위젯을 갱신한다. 다만 스냅샷 생성이 비싸고 호출이
  /// 몰려 들어오므로 스로틀로 합친다(자세한 근거는 [WidgetSyncThrottle] 참조).
  late final _widgetSyncThrottle = WidgetSyncThrottle(
    // 요청을 유발한 프레임을 막지 않도록 그 프레임을 넘긴 뒤 생성한다.
    onSync: () => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWidgetSnapshot();
    }),
  );
  final _initialLinkChecked = Completer<void>();
  StreamSubscription<Uri>? _linkSub;
  bool _handlingLink = false;
  bool _suppressStartupPromptsForShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appMetadataProvider.future);
    });

    // 공유 링크 수신: 콜드스타트 1회 + 실행 중 스트림.
    unawaited(_initIncomingLinks());
    _linkSub = _appLinks.uriLinkStream.listen(_onIncomingLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupPrompts());
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
    _widgetSyncThrottle.dispose();
  }

  Future<void> _initIncomingLinks() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return;
      final outcome = resolveIncomingLink(uri);
      if (outcome is ShareLinkDraft || outcome is ShareLinkNeedsUpdate) {
        _suppressStartupPromptsForShare = true;
        unawaited(_onIncomingLink(uri));
      }
    } catch (error, stackTrace) {
      debugPrint('[KCC share] 초기 공유 링크 확인 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_initialLinkChecked.isCompleted) _initialLinkChecked.complete();
    }
  }

  Future<void> _runStartupPrompts() async {
    await _initialLinkChecked.future;
    if (!mounted || _suppressStartupPromptsForShare) return;

    if (adsEnabled) {
      // Consent → ATT → Mobile Ads SDK, after the first frame (no-op off mobile).
      await initAds();
      if (!mounted) return;
    }

    final context = _rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await maybeShowBackupRestoreNotice(context, ref);
    if (!mounted || _suppressStartupPromptsForShare) return;

    final reminderContext = _rootNavigatorKey.currentContext;
    if (reminderContext == null || !reminderContext.mounted) return;
    await maybeShowBackupReminder(reminderContext, ref);
    if (!mounted || _suppressStartupPromptsForShare) return;

    await _checkAppUpdate();
  }

  Future<void> _onIncomingLink(Uri uri) async {
    if (_handlingLink) return;
    final outcome = resolveIncomingLink(uri);
    if (outcome is! ShareLinkDraft && outcome is! ShareLinkNeedsUpdate) return;
    _handlingLink = true;
    _suppressStartupPromptsForShare = true;
    // 라우터/네비게이터가 준비될 때까지 다음 프레임에서 처리.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final ctx = _rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        if (outcome is ShareLinkNeedsUpdate) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('이 링크를 열려면 앱을 업데이트해 주세요.')),
          );
          return;
        }
        final draft = (outcome as ShareLinkDraft).draft;
        final date = parseEventDate(draft.date);
        // 해당 날짜 화면으로 이동하되, 콜드스타트 때 먼저 생긴 기본 달력
        // 화면을 히스토리에 남기지 않는다. 그래야 에디터에서 뒤로 간 뒤
        // Android 뒤로가기 소프트키가 같은 달력 화면을 한 번 더 보여주지 않는다.
        _router.pushReplacement('${monthPath(YearMonth.of(date))}/${date.day}');
        final freshCtx = await _nextFrameContext();
        if (freshCtx == null || !freshCtx.mounted) return;
        await showEventEditor(freshCtx, date: date, draft: draft);
      } catch (error, stackTrace) {
        // 이 경로는 플랫폼 딥링크 수신이라 자동 테스트가 없어, 실기기에서
        // 조용히 실패하면 원인을 알 수 없다. 콘솔에 최소한의 진단 로그를 남긴다.
        debugPrint('[KCC share] 공유 링크 처리 실패: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        // 콜백 안에서 어떤 경로로 끝나든(정상 리턴/예외) 가드를 반드시 해제해
        // 이후 링크가 영구히 무시되지 않도록 한다.
        _handlingLink = false;
      }
    });
  }

  /// `_router.go()` 직후 예약된 리빌드가 끝나는 다음 프레임까지 기다린 뒤,
  /// 그 시점의 루트 네비게이터 컨텍스트를 반환한다(마운트 해제됐으면 null).
  Future<BuildContext?> _nextFrameContext() {
    final completer = Completer<BuildContext?>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rootNavigatorKey.currentContext;
      completer.complete(ctx != null && ctx.mounted ? ctx : null);
    });
    return completer.future;
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

  /// Lays out the app in a narrower logical viewport without scaling it. This
  /// lets a wider simulator exercise the same breakpoints as a 320px device.
  Widget _withForcedLayoutWidth(BuildContext context, Widget child) {
    if (_forcedLayoutWidth <= 0) return child;

    final media = MediaQuery.of(context);
    final width = math.min(_forcedLayoutWidth.toDouble(), media.size.width);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        height: media.size.height,
        child: MediaQuery(
          data: media.copyWith(size: Size(width, media.size.height)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      calendarControllerProvider,
      (_, _) => _widgetSyncThrottle.request(),
    );
    ref.listen(eventStoreProvider, (_, _) => _widgetSyncThrottle.request());

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
        if (!adsEnabled) return _withForcedLayoutWidth(context, content);
        return Column(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  // 광고 배너는 하단에 '배너 높이 + 세이프영역'만큼 고정되어 있으므로
                  // (maintainBottomViewPadding), 자식의 키보드 인셋을 그만큼 줄여야
                  // 버튼과 키보드 사이에 공백이 생기지 않는다.
                  final adReserved =
                      bottomAdBannerHeight + media.viewPadding.bottom;
                  final reduced = (media.viewInsets.bottom - adReserved).clamp(
                    0.0,
                    double.infinity,
                  );
                  return _withForcedLayoutWidth(
                    context,
                    MediaQuery(
                      data: media.copyWith(
                        viewInsets: EdgeInsets.fromLTRB(
                          media.viewInsets.left,
                          media.viewInsets.top,
                          media.viewInsets.right,
                          reduced,
                        ),
                      ),
                      child: content,
                    ),
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
