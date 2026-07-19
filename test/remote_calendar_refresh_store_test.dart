import 'package:catholic_calendar/features/calendar/data/remote_calendar_refresh_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('allows refresh when a month has never been checked', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RemoteCalendarRefreshStore(prefs: prefs);

    expect(store.shouldRefresh('2026-07'), isTrue);
  });

  test('skips refresh inside the TTL and allows it after the TTL', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 7, 19, 10);
    final store = RemoteCalendarRefreshStore(
      prefs: prefs,
      ttl: const Duration(hours: 24),
      clock: () => now,
    );

    await store.markChecked('2026-07');

    now = DateTime(2026, 7, 20, 9, 59);
    expect(store.shouldRefresh('2026-07'), isFalse);

    now = DateTime(2026, 7, 20, 10);
    expect(store.shouldRefresh('2026-07'), isTrue);
  });

  test('zero TTL always allows refresh', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RemoteCalendarRefreshStore(prefs: prefs, ttl: Duration.zero);

    await store.markChecked('2026-07');

    expect(store.shouldRefresh('2026-07'), isTrue);
  });
}
