import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the self-hosted KCC API as the default base URL', () {
    expect(kRemoteBaseUrl, 'https://api.sidore.org/kcc/v1');
  });

  test('builds month URLs below the configured API base path', () {
    const source = RemoteCalendarSource(
      baseUrl: 'http://127.0.0.1:18080/kcc/v1/',
    );

    expect(
      source.monthUri(2026, 7).toString(),
      'http://127.0.0.1:18080/kcc/v1/calendar/2026/7',
    );
  });
}
