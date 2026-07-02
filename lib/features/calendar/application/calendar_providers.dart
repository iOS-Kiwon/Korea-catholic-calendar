import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calendar_data_repository.dart';
import '../data/calendar_service.dart';

/// The data repository (bundled-asset loader).
final calendarDataRepositoryProvider = Provider<CalendarDataRepository>(
  (ref) => const CalendarDataRepository(),
);

/// The loaded calendar service (CBCK snapshot over the computed engine). Async
/// because data is loaded from assets; resolves once and is cached.
///
/// The visible month and selected day are carried in the router URL
/// (`/2026/07`, `/2026/07/02`), so they are not modelled as providers.
final liturgicalCalendarProvider = FutureProvider<CalendarService>((ref) {
  return ref.watch(calendarDataRepositoryProvider).load();
});
