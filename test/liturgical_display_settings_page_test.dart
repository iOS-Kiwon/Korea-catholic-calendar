import 'package:catholic_calendar/features/calendar/application/liturgical_display_filter.dart';
import 'package:catholic_calendar/features/settings/presentation/liturgical_display_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('4개 옵션 렌더 + 선택 시 저장', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LiturgicalDisplaySettingsPage()),
      ),
    );
    // 미리보기의 calendarControllerProvider는 번들 에셋을 비동기 로드하며 fake-async
    // 테스트 존에서는 완료되지 않을 수 있다(로딩 인디케이터가 계속 애니메이션함).
    // pumpAndSettle은 그 무한 애니메이션 때문에 타임아웃하므로, 라디오/텍스트가
    // 렌더되기에 충분한 pump만 수행한다.
    await tester.pump();
    await tester.pump();

    expect(find.text('모든 전례일'), findsOneWidget);
    expect(find.text('대축일/축일만'), findsOneWidget);
    expect(find.text('주일에 대축일만'), findsOneWidget);
    expect(find.text('표시 안함'), findsOneWidget);

    // '모든 전례일' 선택 -> 프로바이더 값 변경.
    await tester.tap(find.text('모든 전례일'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiturgicalDisplaySettingsPage)),
    );
    expect(
      container.read(liturgicalDisplayFilterProvider),
      LiturgicalDisplayFilter.all,
    );
  });
}
