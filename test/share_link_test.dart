import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/sharing/share_link.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _ev({
  String date = '2026-08-10',
  String? endDate,
  String? time,
  String? endTime,
  String? memo,
  String name = '본당 미사',
  int color = 0xFFEF6C00,
}) => CalendarEvent(
  id: 'e1', date: date, endDate: endDate, categoryId: 'c1',
  categoryName: name, categoryColor: color, memo: memo, time: time, endTime: endTime,
);

SharedEventDraft _draftOf(Uri uri) {
  final o = resolveIncomingLink(uri);
  return (o as ShareLinkDraft).draft;
}

void main() {
  test('시간 일정 왕복(한글 카테고리/메모 포함)', () {
    final uri = buildShareUri(_ev(time: '09:00', endTime: '10:00', memo: '9시 미사 후 성가대 연습'));
    expect(uri.host, 'kcc.sidore.org');
    expect(uri.pathSegments.first, 'e');
    final d = _draftOf(uri);
    expect(d.date, '2026-08-10');
    expect(d.time, '09:00');
    expect(d.endTime, '10:00');
    expect(d.memo, '9시 미사 후 성가대 연습');
    expect(d.categoryName, '본당 미사');
    expect(d.categoryColor, 0xFFEF6C00);
  });

  test('종일 일정: t/et 생략', () {
    final uri = buildShareUri(_ev(time: null));
    final d = _draftOf(uri);
    expect(d.time, isNull);
    expect(d.endTime, isNull);
  });

  test('다일 일정: ed 포함, 단일일이면 ed 생략', () {
    expect(_draftOf(buildShareUri(_ev(endDate: '2026-08-12'))).endDate, '2026-08-12');
    expect(_draftOf(buildShareUri(_ev(endDate: '2026-08-10'))).endDate, isNull);
  });

  test('빈/공백 메모는 생략', () {
    expect(_draftOf(buildShareUri(_ev(memo: '   '))).memo, isNull);
  });

  test('커스텀 스킴 폴백도 파싱', () {
    final https = buildShareUri(_ev(time: '09:00'));
    final payload = https.pathSegments[1];
    final custom = Uri.parse('catholiccalendar://e/$payload');
    expect(_draftOf(custom).time, '09:00');
  });

  test('손상 입력은 Invalid', () {
    expect(resolveIncomingLink(Uri.parse('https://kcc.sidore.org/e/@@notbase64@@')), isA<ShareLinkInvalid>());
    expect(resolveIncomingLink(Uri.parse('https://kcc.sidore.org/e/')), isA<ShareLinkInvalid>());
    expect(resolveIncomingLink(Uri.parse('https://example.com/e/abc')), isA<ShareLinkInvalid>());
  });

  test('지원보다 높은 버전은 NeedsUpdate', () {
    // v=9 payload를 직접 구성
    final o = resolveIncomingLink(Uri.parse('https://kcc.sidore.org/e/${encodeTestPayload({'v': 9, 'd': '2026-08-10'})}'));
    expect(o, isA<ShareLinkNeedsUpdate>());
  });

  test('buildShareText에 링크와 날짜 포함', () {
    final text = buildShareText(_ev(time: '09:00', memo: '메모A'));
    expect(text, contains('https://kcc.sidore.org/e/'));
    expect(text, contains('8월 10일'));
    expect(text, contains('메모A'));
  });
}
