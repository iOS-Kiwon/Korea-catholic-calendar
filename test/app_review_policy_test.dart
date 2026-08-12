import 'package:catholic_calendar/features/app_review/app_review_policy.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event(String id) => CalendarEvent(
  id: id,
  date: '2026-08-10',
  categoryId: 'c1',
  categoryName: '본당 행사',
);

void main() {
  group('shouldRequestReview', () {
    test('일정이 5개 이상이면 요청한다', () {
      expect(
        shouldRequestReview(
          remoteEnabled: true,
          requestedAt: null,
          eventCount: 5,
        ),
        isTrue,
      );
    });

    test('일정이 4개면 요청하지 않는다', () {
      expect(
        shouldRequestReview(
          remoteEnabled: true,
          requestedAt: null,
          eventCount: 4,
        ),
        isFalse,
      );
    });

    test('일정이 5개를 넘어도 요청한다', () {
      expect(
        shouldRequestReview(
          remoteEnabled: true,
          requestedAt: null,
          eventCount: 12,
        ),
        isTrue,
      );
    });

    test('이미 요청한 적 있으면 조건을 만족해도 요청하지 않는다', () {
      expect(
        shouldRequestReview(
          remoteEnabled: true,
          requestedAt: DateTime.utc(2026, 8, 1),
          eventCount: 12,
        ),
        isFalse,
      );
    });

    test('킬스위치가 꺼져 있으면 요청하지 않는다', () {
      expect(
        shouldRequestReview(
          remoteEnabled: false,
          requestedAt: null,
          eventCount: 12,
        ),
        isFalse,
      );
    });
  });

  group('countStoredEvents', () {
    test('빈 맵은 0', () {
      expect(countStoredEvents(const {}), 0);
    });

    test('날짜별 리스트 길이를 모두 더한다', () {
      final events = {
        '2026-08-10': [_event('a'), _event('b')],
        '2026-08-11': [_event('c')],
      };

      expect(countStoredEvents(events), 3);
    });

    test('반복 일정도 엔트리 하나이므로 1개로 센다', () {
      final events = {
        '2026-08-10': [_event('yearly')],
      };

      expect(countStoredEvents(events), 1);
    });
  });
}
