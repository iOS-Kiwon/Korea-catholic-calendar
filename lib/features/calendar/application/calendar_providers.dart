import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../data/calendar_data_repository.dart';

/// The data repository (bundled-asset loader).
final calendarDataRepositoryProvider = Provider<CalendarDataRepository>(
  (ref) => const CalendarDataRepository(),
);

/// The loaded, ready-to-query engine. Async because the dataset is loaded from
/// assets; resolves once and is cached for the session.
///
/// The visible month and selected day are carried in the router URL
/// (`/2026/07`, `/2026/07/02`), so they are not modelled as providers.
final liturgicalCalendarProvider = FutureProvider<LiturgicalCalendar>((ref) {
  return ref.watch(calendarDataRepositoryProvider).load();
});
