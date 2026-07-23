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

  testWidgets('열었다 닫은 뒤에는 스크림이 사라져 아래 위젯이 탭을 받는다', (tester) async {
    var behindTapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // 스피드다이얼 아래 깔린 전체 화면 위젯. 스크림이 닫힌 뒤에도
              // 남아있으면 이 탭이 흡수되어 카운트가 증가하지 않는다.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => behindTapCount++,
                ),
              ),
              SizedBox.expand(
                child: SpeedDialFab(
                  color: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.all(16),
                  onAddEvent: () {},
                  onAddFeast: () {},
                  onOpenSettings: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 연다.
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsOneWidget);

    // 다시 눌러 닫는다(닫힘 애니메이션이 dismissed까지 완료되도록 settle).
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsNothing);

    // FAB에서 멀리 떨어진 위치를 탭하면 스크림이 남아있지 않아야 아래
    // 위젯까지 탭이 전달된다.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(behindTapCount, 1);
  });
}
