/// 한국 천주교 전례력 계산 엔진 (pure Dart, offline).
///
/// Public barrel. Exports the facade, data model and pure helpers that the
/// application layer is allowed to depend on.
library;

export 'src/calendar.dart';
export 'src/core/computus.dart';
export 'src/data/default_dataset.dart';
export 'src/data/schema.dart'
    show CalendarDataset, CalendarAdaptation, CalendarDataFormatException;
export 'src/model/celebration.dart';
export 'src/model/enums.dart';
export 'src/model/liturgical_day.dart';
export 'src/model/precedence_code.dart';
