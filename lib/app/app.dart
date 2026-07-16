import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../features/ads/ads.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CatholicCalendarApp extends StatefulWidget {
  const CatholicCalendarApp({super.key});

  @override
  State<CatholicCalendarApp> createState() => _CatholicCalendarAppState();
}

class _CatholicCalendarAppState extends State<CatholicCalendarApp> {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    if (adsEnabled) {
      // Consent → ATT → Mobile Ads SDK, after the first frame (no-op off mobile).
      WidgetsBinding.instance.addPostFrameCallback((_) => initAds());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '가톨릭 달력',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
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
