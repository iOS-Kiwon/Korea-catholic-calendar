import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/sharing/event_sharer.dart';
import 'package:catholic_calendar/features/sharing/event_share_button.dart';
import 'package:catholic_calendar/features/sharing/share_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CaptureSharer implements EventSharer {
  String? shared;
  @override
  Future<void> share(String text) async => shared = text;
}

void main() {
  testWidgets('공유 버튼 탭 시 buildShareText로 공유 호출', (tester) async {
    final sharer = _CaptureSharer();
    const event = CalendarEvent(
      id: 'e1', date: '2026-08-10', categoryId: 'c1', categoryName: '본당 미사',
      categoryColor: 0xFFEF6C00, time: '09:00', memo: '메모A',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [eventSharerProvider.overrideWithValue(sharer)],
      child: const MaterialApp(home: Scaffold(body: EventShareButton(event: event))),
    ));
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();
    expect(sharer.shared, buildShareText(event));
    expect(sharer.shared, contains('https://kcc.sidore.org/e/'));
  });
}
