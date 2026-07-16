import 'package:catholic_calendar/features/events/data/event_repository.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CalendarEvent', () {
    test('toJson/fromJson round-trips all fields', () {
      const e = CalendarEvent(
        id: 'abc',
        date: '2026-07-16',
        title: '성당 미사',
        memo: '교중 미사',
        time: '10:30',
        notify: true,
      );
      final decoded = CalendarEvent.fromJson(e.toJson());
      expect(decoded.id, 'abc');
      expect(decoded.date, '2026-07-16');
      expect(decoded.title, '성당 미사');
      expect(decoded.memo, '교중 미사');
      expect(decoded.time, '10:30');
      expect(decoded.notify, true);
    });

    test('optional fields survive as null with sensible defaults', () {
      const e = CalendarEvent(id: 'x', date: '2026-07-16', title: '단식');
      final decoded = CalendarEvent.fromJson(e.toJson());
      expect(decoded.memo, isNull);
      expect(decoded.time, isNull);
      expect(decoded.notify, true); // 기본값: 알림 켜짐
    });

    test('copyWith replaces only the given fields', () {
      const e = CalendarEvent(id: 'x', date: '2026-07-16', title: 'a');
      final e2 = e.copyWith(title: 'b', time: '09:00');
      expect(e2.id, 'x');
      expect(e2.date, '2026-07-16');
      expect(e2.title, 'b');
      expect(e2.time, '09:00');
    });

    test('isAllDay reflects absence of a time', () {
      const allDay = CalendarEvent(id: '1', date: '2026-07-16', title: 'a');
      const timed = CalendarEvent(
        id: '2',
        date: '2026-07-16',
        title: 'b',
        time: '09:00',
      );
      expect(allDay.isAllDay, isTrue);
      expect(timed.isAllDay, isFalse);
    });
  });

  group('EventRepository', () {
    late EventRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = EventRepository(prefs);
    });

    test('empty store loads as an empty map', () {
      expect(repo.load(), isEmpty);
    });

    test('save then load round-trips events keyed by date', () async {
      final map = {
        '2026-07-16': [
          const CalendarEvent(
            id: '1',
            date: '2026-07-16',
            title: '미사',
            time: '10:00',
          ),
          const CalendarEvent(id: '2', date: '2026-07-16', title: '고해성사'),
        ],
        '2026-07-20': [
          const CalendarEvent(
            id: '3',
            date: '2026-07-20',
            title: '성경공부',
            memo: '루카복음',
            notify: false,
          ),
        ],
      };
      await repo.save(map);

      final loaded = repo.load();
      expect(loaded.keys, containsAll(['2026-07-16', '2026-07-20']));
      expect(loaded['2026-07-16'], hasLength(2));
      expect(loaded['2026-07-16']![0].title, '미사');
      expect(loaded['2026-07-16']![0].time, '10:00');
      expect(loaded['2026-07-20']![0].memo, '루카복음');
      expect(loaded['2026-07-20']![0].notify, isFalse);
    });

    test('save persists across repository instances (same prefs)', () async {
      await repo.save({
        '2026-07-16': [
          const CalendarEvent(id: '1', date: '2026-07-16', title: 'x'),
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo2 = EventRepository(prefs);
      expect(repo2.load()['2026-07-16'], hasLength(1));
    });

    test('saving an empty map clears the store', () async {
      await repo.save({
        '2026-07-16': [
          const CalendarEvent(id: '1', date: '2026-07-16', title: 'x'),
        ],
      });
      await repo.save({});
      expect(repo.load(), isEmpty);
    });
  });
}
