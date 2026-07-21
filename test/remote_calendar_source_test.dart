import 'dart:convert';

import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

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

  test('parses available month responses from the self-hosted API', () async {
    final source = RemoteCalendarSource(
      baseUrl: 'https://api.sidore.org/kcc/v1',
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.sidore.org/kcc/v1/calendar/2026/7',
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'year': 2026,
              'month': 7,
              'available': true,
              'days': [
                {
                  'date': '2026-07-15',
                  'title': '백오피스 수정 기념일',
                  'color': 'white',
                  'readings': ['① 이사 10,5-7.13-16'],
                  'url': 'https://missa.cbck.or.kr/DailyMissa/20260715',
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final days = await source.fetchMonth(2026, 7);

    expect(days, isNotNull);
    expect(days!['2026-07-15']?.title, '백오피스 수정 기념일');
    expect(days['2026-07-15']?.color, LiturgicalColor.white);
    expect(days['2026-07-15']?.readings, hasLength(1));
  });

  test('returns null for unavailable or failed month responses', () async {
    final unavailable = RemoteCalendarSource(
      client: MockClient(
        (_) async =>
            http.Response('{"year":2026,"month":8,"available":false}', 200),
      ),
    );
    final missing = RemoteCalendarSource(
      client: MockClient((_) async => http.Response('not found', 404)),
    );

    expect(await unavailable.fetchMonth(2026, 8), isNull);
    expect(await missing.fetchMonth(2026, 8), isNull);
  });
}
