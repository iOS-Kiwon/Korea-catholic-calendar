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

/// Calendar service that renders immediately from the bundled snapshot +
/// computed engine, then enriches months from the gateway in the background.
final calendarControllerProvider =
    AsyncNotifierProvider<CalendarController, CalendarService>(
      CalendarController.new,
    );

class CalendarController extends AsyncNotifier<CalendarService> {
  final Set<String> _loading = {};
  final Set<String> _unavailable = {};

  @override
  Future<CalendarService> build() {
    return ref.watch(liturgicalCalendarProvider.future);
  }

  Future<void> preloadAround(YearMonth month) async {
    await Future.wait([
      ensureMonth(month),
      ensureMonth(month.previous),
      ensureMonth(month.next),
    ]);
  }

  Future<void> ensureMonth(YearMonth month) async {
    final key = month.toString();
    final service = state.hasValue ? state.requireValue : null;
    if (service == null ||
        service.hasMonth(month.year, month.month) ||
        _loading.contains(key) ||
        _unavailable.contains(key)) {
      return;
    }

    _loading.add(key);
    try {
      final more = await ref
          .read(remoteCalendarSourceProvider)
          .fetchMonth(month.year, month.month);
      if (more == null || more.isEmpty) {
        _unavailable.add(key);
        return;
      }
      service.merge(more);
      state = AsyncData(service);
    } catch (_) {
      _unavailable.add(key);
    } finally {
      _loading.remove(key);
    }
  }
}

/// Legacy provider kept for tests/older call sites. Prefer
/// [calendarControllerProvider] for UI so navigation never waits on the network.
///
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
