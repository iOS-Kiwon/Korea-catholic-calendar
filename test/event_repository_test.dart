import 'package:catholic_calendar/features/events/data/event_repository.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalendarEvent _event({
  required String id,
  required String date,
  String categoryId = 'c1',
  String categoryName = '본당 행사',
  int categoryColor = 0xFF283593,
  String? memo,
  String? time,
  bool notify = true,
}) => CalendarEvent(
  id: id,
  date: date,
  categoryId: categoryId,
  categoryName: categoryName,
  categoryColor: categoryColor,
  memo: memo,
  time: time,
  notify: notify,
);

void main() {
  group('CalendarEvent', () {
    test('toJson/fromJson round-trips all fields', () {
      final e = _event(
        id: 'abc',
        date: '2026-07-16',
        categoryId: 'cat1',
        categoryName: '성당 청소',
        categoryColor: 0xFF2E7D32,
        memo: '2조',
        time: '10:30',
        notify: true,
      );
      final decoded = CalendarEvent.fromJson(e.toJson());
      expect(decoded.id, 'abc');
      expect(decoded.date, '2026-07-16');
      expect(decoded.categoryId, 'cat1');
      expect(decoded.categoryName, '성당 청소');
      expect(decoded.title, '성당 청소'); // title == categoryName
      expect(decoded.categoryColor, 0xFF2E7D32);
      expect(decoded.memo, '2조');
      expect(decoded.time, '10:30');
      expect(decoded.notify, true);
    });

    test('optional fields survive as null with sensible defaults', () {
      final e = _event(id: 'x', date: '2026-07-16');
      final decoded = CalendarEvent.fromJson(e.toJson());
      expect(decoded.memo, isNull);
      expect(decoded.time, isNull);
      expect(decoded.notify, true); // 기본값: 알림 켜짐
    });

    test('reads legacy free-text title as the category name', () {
      final decoded = CalendarEvent.fromJson({
        'id': '1',
        'date': '2026-07-16',
        'title': '옛 일정',
        'notify': true,
      });
      expect(decoded.categoryName, '옛 일정');
      expect(decoded.categoryColor, kDefaultEventColor);
    });

    test('copyWith replaces only the given fields', () {
      final e = _event(id: 'x', date: '2026-07-16', categoryName: 'a');
      final e2 = e.copyWith(categoryName: 'b', time: '09:00');
      expect(e2.id, 'x');
      expect(e2.date, '2026-07-16');
      expect(e2.categoryName, 'b');
      expect(e2.time, '09:00');
    });

    test('isAllDay reflects absence of a time', () {
      final allDay = _event(id: '1', date: '2026-07-16');
      final timed = _event(id: '2', date: '2026-07-16', time: '09:00');
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
          _event(id: '1', date: '2026-07-16', categoryName: '미사', time: '10:00'),
          _event(id: '2', date: '2026-07-16', categoryName: '고해성사'),
        ],
        '2026-07-20': [
          _event(
            id: '3',
            date: '2026-07-20',
            categoryName: '성경공부',
            memo: '루카복음',
            notify: false,
          ),
        ],
      };
      await repo.save(map);

      final loaded = repo.load();
      expect(loaded.keys, containsAll(['2026-07-16', '2026-07-20']));
      expect(loaded['2026-07-16'], hasLength(2));
      expect(loaded['2026-07-16']![0].categoryName, '미사');
      expect(loaded['2026-07-16']![0].time, '10:00');
      expect(loaded['2026-07-20']![0].memo, '루카복음');
      expect(loaded['2026-07-20']![0].notify, isFalse);
    });

    test('save persists across repository instances (same prefs)', () async {
      await repo.save({
        '2026-07-16': [_event(id: '1', date: '2026-07-16')],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo2 = EventRepository(prefs);
      expect(repo2.load()['2026-07-16'], hasLength(1));
    });

    test('saving an empty map clears the store', () async {
      await repo.save({
        '2026-07-16': [_event(id: '1', date: '2026-07-16')],
      });
      await repo.save({});
      expect(repo.load(), isEmpty);
    });
  });
}
