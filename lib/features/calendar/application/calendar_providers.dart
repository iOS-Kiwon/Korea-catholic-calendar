import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/year_month.dart';
import '../data/calendar_data_repository.dart';
import '../data/calendar_service.dart';
import '../data/remote_calendar_source.dart';

void _debugLog(String message) {
  if (kDebugMode) debugPrint(message);
}

/// The data repository (bundled-asset loader).
final calendarDataRepositoryProvider = Provider<CalendarDataRepository>(
  (ref) => const CalendarDataRepository(),
);

/// The self-hosted KCC API client.
final remoteCalendarSourceProvider = Provider<RemoteCalendarSource>(
  (ref) => const RemoteCalendarSource(),
);

enum RemoteMonthStatus { idle, loading, loaded, unavailable, failed }

class RemoteMonthState {
  const RemoteMonthState({
    required this.status,
    required this.message,
    required this.checkedAt,
  });

  final RemoteMonthStatus status;
  final String message;
  final DateTime checkedAt;
}

final remoteMonthStatusProvider =
    NotifierProvider<
      RemoteMonthStatusController,
      Map<String, RemoteMonthState>
    >(RemoteMonthStatusController.new);

class RemoteMonthStatusController
    extends Notifier<Map<String, RemoteMonthState>> {
  @override
  Map<String, RemoteMonthState> build() => const {};

  void setMonth(String key, RemoteMonthStatus status, String message) {
    state = {
      ...state,
      key: RemoteMonthState(
        status: status,
        message: message,
        checkedAt: DateTime.now(),
      ),
    };
  }
}

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
  final Set<String> _loadedFromRemote = {};
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
        _loading.contains(key) ||
        _loadedFromRemote.contains(key) ||
        _unavailable.contains(key)) {
      return;
    }

    _loading.add(key);
    _setRemoteStatus(key, RemoteMonthStatus.loading, '서버 확인 중');
    try {
      final more = await ref
          .read(remoteCalendarSourceProvider)
          .fetchMonth(month.year, month.month);
      if (more == null || more.isEmpty) {
        _unavailable.add(key);
        _setRemoteStatus(key, RemoteMonthStatus.unavailable, '서버 데이터 없음');
        _debugLog('[KCC API] $key fallback to bundled calendar');
        return;
      }
      service.merge(more);
      _loadedFromRemote.add(key);
      _setRemoteStatus(key, RemoteMonthStatus.loaded, '서버 갱신 완료');
      _debugLog('[KCC API] $key merged into CalendarService');
      state = AsyncData(service);
    } catch (error) {
      _unavailable.add(key);
      _setRemoteStatus(key, RemoteMonthStatus.failed, '서버 확인 실패');
      _debugLog('[KCC API] $key merge failed: $error');
    } finally {
      _loading.remove(key);
    }
  }

  void _setRemoteStatus(String key, RemoteMonthStatus status, String message) {
    ref.read(remoteMonthStatusProvider.notifier).setMonth(key, status, message);
  }
}

/// Legacy provider kept for tests/older call sites. Prefer
/// [calendarControllerProvider] for UI so navigation never waits on the network.
///
/// The service enriched with authoritative data for a specific month.
///
/// The gateway is attempted even when the bundled snapshot already has that
/// month, so backoffice fixes can override the app bundle. On failure/미발행 the
/// base service is returned (앱은 번들 스냅샷 + 계산 엔진으로 폴백). Merges are
/// cached in the shared service, so revisiting a month is instant.
final monthServiceProvider = FutureProvider.family<CalendarService, YearMonth>((
  ref,
  ym,
) async {
  final service = await ref.watch(liturgicalCalendarProvider.future);
  final more = await ref
      .watch(remoteCalendarSourceProvider)
      .fetchMonth(ym.year, ym.month);
  if (more != null) service.merge(more);
  return service;
});
