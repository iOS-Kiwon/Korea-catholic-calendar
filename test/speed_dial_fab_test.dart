import 'package:catholic_calendar/features/calendar/presentation/widgets/speed_dial_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required VoidCallback onAddEvent}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // Align으로 감싸면 SpeedDialFab이 자기 콘텐츠 크기로 shrink-wrap 되어
        // 스크림이 화면 전체를 덮지 못한다. 화면 전체 크기를 그대로 넘겨준다.
        body: SizedBox.expand(
          child: SpeedDialFab(
            color: const Color(0xFF2E7D32),
            padding: const EdgeInsets.all(16),
            onAddEvent: onAddEvent,
            onAddFeast: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('처음엔 항목 라벨이 보이지 않는다', (tester) async {
    await _pump(tester, onAddEvent: () {});
    expect(find.text('일정 추가'), findsNothing);
    expect(find.text('축일 추가'), findsNothing);
    expect(find.text('설정'), findsNothing);
  });

  testWidgets('메인 버튼을 누르면 3개 항목이 나타난다', (tester) async {
    await _pump(tester, onAddEvent: () {});
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsOneWidget);
    expect(find.text('축일 추가'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('항목을 누르면 콜백이 실행되고 닫힌다', (tester) async {
    var tapped = false;
    await _pump(tester, onAddEvent: () => tapped = true);
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정 추가'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(find.text('일정 추가'), findsNothing);
  });

  testWidgets('스크림이 화면 전체를 덮어 멀리 떨어진 탭에도 닫힌다', (tester) async {
    await _pump(tester, onAddEvent: () {});
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsOneWidget);
    expect(find.text('축일 추가'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);

    // FAB에서 멀리 떨어진 화면 좌상단을 탭해도 스크림이 흡수해 닫혀야 한다.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsNothing);
  });
}
