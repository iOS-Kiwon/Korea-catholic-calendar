import 'event_category.dart';

/// The fixed palette users pick category colors from (ARGB ints).
const List<int> kCategoryColors = [
  0xFF283593, // indigo
  0xFF1565C0, // blue
  0xFF00838F, // cyan
  0xFF2E7D32, // green
  0xFF558B2F, // light green
  0xFFF9A825, // amber
  0xFFEF6C00, // orange
  0xFFC62828, // red
  0xFFAD1457, // pink
  0xFF6A1B9A, // purple
  0xFF4E342E, // brown
  0xFF455A64, // blue grey
];

/// Starter categories seeded on first run. Fully editable/deletable afterwards.
const List<EventCategory> kDefaultCategories = [
  EventCategory(id: 'seed-parish', name: '본당 행사', color: 0xFF283593),
  EventCategory(id: 'seed-diocese', name: '교구 행사', color: 0xFF6A1B9A),
  EventCategory(id: 'seed-prayer', name: '기도', color: 0xFF1565C0),
  EventCategory(id: 'seed-liturgy', name: '전례', color: 0xFF2E7D32),
  EventCategory(id: 'seed-catechesis', name: '교리', color: 0xFFEF6C00),
];
