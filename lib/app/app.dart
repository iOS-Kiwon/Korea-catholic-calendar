import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_update/app_update_service.dart';
import '../features/ads/ads.dart';
import '../features/events/application/category_providers.dart';
import '../features/events/application/event_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CatholicCalendarApp extends ConsumerStatefulWidget {
  const CatholicCalendarApp({super.key});

  @override
  ConsumerState<CatholicCalendarApp> createState() =>
      _CatholicCalendarAppState();
}

class _CatholicCalendarAppState extends ConsumerState<CatholicCalendarApp> {
  late final GoRouter _router = buildRouter();

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

    await showDialog<void>(
      context: context,
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '가톨릭 달력',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light, // 다크 모드 미지원 — 항상 라이트 테마
      routerConfig: _router,
      // 모든 화면 하단(SafeArea.bottom 바로 위)에 배너 광고 배치.
      builder: (context, child) => Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          if (adsEnabled) const BottomAdBanner(),
        ],
      ),
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
