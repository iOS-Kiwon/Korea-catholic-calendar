import 'package:catholic_calendar/features/events/application/category_providers.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotifications implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> sync(Map<String, List<CalendarEvent>> events) async {}
}

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(_FakeNotifications()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

CalendarEvent _eventFor(dynamic category) => CalendarEvent(
  id: 'e1',
  date: '2026-07-16',
  categoryId: category.id as String,
  categoryName: category.name as String,
  categoryColor: category.color as int,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first run seeds the default categories', () async {
    final c = _container();
    final categories = await c.read(categoriesProvider.future);
    expect(categories, isNotEmpty);
    expect(categories.map((e) => e.name), contains('본당 행사'));
  });

  test('replaceAll rename/recolor propagates into existing events', () async {
    final c = _container();
    final categories = await c.read(categoriesProvider.future);
    final cat = categories.first;

    await c.read(eventStoreProvider.notifier).add(_eventFor(cat));

    final edited = [
      cat.copyWith(name: '본당 대축제', color: 0xFFC62828),
      ...categories.skip(1),
    ];
    await c.read(categoriesProvider.notifier).replaceAll(edited);

    final events = await c.read(eventStoreProvider.future);
    final saved = events['2026-07-16']!.single;
    expect(saved.categoryName, '본당 대축제');
    expect(saved.categoryColor, 0xFFC62828);
  });

  test('replaceAll persists a new order', () async {
    final c = _container();
    final categories = await c.read(categoriesProvider.future);
    final reordered = [categories[1], categories[0], ...categories.skip(2)];

    await c.read(categoriesProvider.notifier).replaceAll(reordered);

    final after = await c.read(categoriesProvider.future);
    expect(after.first.id, categories[1].id);
    expect(after[1].id, categories[0].id);
  });

  test('inUseCategoryIdsProvider reflects events (for delete-blocking)', () async {
    final c = _container();
    final cat = (await c.read(categoriesProvider.future)).first;
    await c.read(eventStoreProvider.future);

    expect(c.read(inUseCategoryIdsProvider), isEmpty);

    await c.read(eventStoreProvider.notifier).add(_eventFor(cat));
    expect(c.read(inUseCategoryIdsProvider), contains(cat.id));
  });

  test('replaceAll with an empty list does not re-seed on next build', () async {
    final c = _container();
    await c.read(categoriesProvider.future);
    await c.read(categoriesProvider.notifier).replaceAll(const []);
    expect(await c.read(categoriesProvider.future), isEmpty);

    // A fresh container over the same (mock) prefs must stay empty.
    final c2 = _container();
    expect(await c2.read(categoriesProvider.future), isEmpty);
  });
}
