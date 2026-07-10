import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/year_month.dart';
import '../data/calendar_data_repository.dart';
import '../data/calendar_service.dart';
import '../data/remote_calendar_source.dart';

/// The data repository (bundled-asset loader).
final calendarDataRepositoryProvider = Provider<CalendarDataRepository>(
  (ref) => const CalendarDataRepository(),
);

/// The caching gateway client (Cloudflare Worker).
final remoteCalendarSourceProvider = Provider<RemoteCalendarSource>(
  (ref) => const RemoteCalendarSource(),
);

/// The base calendar service: bundled snapshot over the computed engine.
/// Loaded once from assets. Async because assets are read at startup.
final liturgicalCalendarProvider = FutureProvider<CalendarService>((ref) {
  return ref.watch(calendarDataRepositoryProvider).load();
});

/// The service enriched with authoritative data for a specific month.
///
/// If the month is not already loaded (bundled), it is fetched once from the
/// gateway and merged in; on failure/미발행 the base service is returned
/// (앱은 번들 스냅샷 + 계산 엔진으로 폴백). Merges are cached in the shared
/// service, so revisiting a month is instant.
final monthServiceProvider = FutureProvider.family<CalendarService, YearMonth>((
  ref,
  ym,
) async {
  final service = await ref.watch(liturgicalCalendarProvider.future);
  if (!service.hasMonth(ym.year, ym.month)) {
    final more = await ref
        .watch(remoteCalendarSourceProvider)
        .fetchMonth(ym.year, ym.month);
    if (more != null) service.merge(more);
  }
  return service;
});
