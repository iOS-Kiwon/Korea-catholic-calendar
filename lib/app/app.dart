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
          const BottomAdBanner(),
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
