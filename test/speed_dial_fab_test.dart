import 'package:catholic_calendar/features/calendar/presentation/widgets/speed_dial_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required VoidCallback onAddEvent}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: SpeedDialFab(
            color: const Color(0xFF2E7D32),
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
}
