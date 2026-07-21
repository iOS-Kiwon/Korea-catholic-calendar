import 'package:catholic_calendar/features/events/data/category_repository.dart';
import 'package:catholic_calendar/features/events/data/event_repository.dart';
import 'package:catholic_calendar/features/events/data/personal_data_backup_repository.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalendarEvent _event({
  required String id,
  required String date,
  String categoryId = 'cat-1',
  String categoryName = '미사',
  int categoryColor = 0xFF2E7D32,
}) => CalendarEvent(
  id: id,
  date: date,
  categoryId: categoryId,
  categoryName: categoryName,
  categoryColor: categoryColor,
);

void main() {
  test('exports local events and categories as a portable snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await EventRepository(prefs).save({
      '2026-07-16': [_event(id: '1', date: '2026-07-16')],
    });
    await CategoryRepository(
      prefs,
    ).save(const [EventCategory(id: 'cat-1', name: '미사', color: 0xFF2E7D32)]);
    await prefs.setBool(CategoryRepository.seededStorageKey, true);

    final snapshot = PersonalDataBackupRepository(prefs).exportSnapshot();
    final json = snapshot.toJson();

    expect(snapshot.schemaVersion, 1);
    expect(snapshot.events['2026-07-16'], hasLength(1));
    expect(snapshot.categories.single.name, '미사');
    expect(snapshot.categoriesSeeded, isTrue);
    expect(json['schemaVersion'], 1);
    expect((json['events'] as Map)['2026-07-16'], hasLength(1));
  });

  test('restores a portable snapshot into local repositories', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final snapshot = PersonalDataSnapshot.fromJson({
      'schemaVersion': 1,
      'exportedAt': '2026-07-19T00:00:00.000Z',
      'events': {
        '2026-07-16': [_event(id: '1', date: '2026-07-16').toJson()],
      },
      'categories': [
        const EventCategory(
          id: 'cat-1',
          name: '미사',
          color: 0xFF2E7D32,
        ).toJson(),
      ],
      'categoriesSeeded': true,
    });

    await PersonalDataBackupRepository(prefs).restoreSnapshot(snapshot);

    expect(EventRepository(prefs).load()['2026-07-16'], hasLength(1));
    expect(CategoryRepository(prefs).load().single.name, '미사');
    expect(prefs.getBool(CategoryRepository.seededStorageKey), isTrue);
  });
}
