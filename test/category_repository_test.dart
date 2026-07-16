import 'package:catholic_calendar/features/events/data/category_repository.dart';
import 'package:catholic_calendar/features/events/model/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EventCategory', () {
    test('toJson/fromJson round-trips', () {
      const c = EventCategory(id: 'a', name: '본당 행사', color: 0xFF283593);
      final decoded = EventCategory.fromJson(c.toJson());
      expect(decoded.id, 'a');
      expect(decoded.name, '본당 행사');
      expect(decoded.color, 0xFF283593);
    });

    test('copyWith replaces only given fields', () {
      const c = EventCategory(id: 'a', name: '모임', color: 0xFFEF6C00);
      final c2 = c.copyWith(name: '주일 모임');
      expect(c2.id, 'a');
      expect(c2.name, '주일 모임');
      expect(c2.color, 0xFFEF6C00);
    });
  });

  group('CategoryRepository', () {
    late CategoryRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = CategoryRepository(prefs);
    });

    test('empty store loads as an empty list', () {
      expect(repo.load(), isEmpty);
    });

    test('save then load preserves order', () async {
      final list = [
        const EventCategory(id: '1', name: '본당 행사', color: 0xFF283593),
        const EventCategory(id: '2', name: '교구 행사', color: 0xFF6A1B9A),
        const EventCategory(id: '3', name: '성당 청소', color: 0xFF2E7D32),
      ];
      await repo.save(list);

      final loaded = repo.load();
      expect(loaded.map((c) => c.id).toList(), ['1', '2', '3']);
      expect(loaded[1].name, '교구 행사');
    });

    test('reordering is persisted', () async {
      await repo.save(const [
        EventCategory(id: '1', name: 'A', color: 0xFF283593),
        EventCategory(id: '2', name: 'B', color: 0xFF6A1B9A),
      ]);
      await repo.save(const [
        EventCategory(id: '2', name: 'B', color: 0xFF6A1B9A),
        EventCategory(id: '1', name: 'A', color: 0xFF283593),
      ]);
      expect(repo.load().map((c) => c.id).toList(), ['2', '1']);
    });

    test('saving an empty list clears the store', () async {
      await repo.save(const [
        EventCategory(id: '1', name: 'A', color: 0xFF283593),
      ]);
      await repo.save(const []);
      expect(repo.load(), isEmpty);
    });
  });
}
