import 'dart:convert';

import 'package:catholic_calendar/features/saints/data/saint_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('builds paged saint search URLs', () {
    const source = SaintSource(baseUrl: 'https://api.example.test/kcc/v1/');

    expect(
      source.searchUri('프란치스코', limit: 30).toString(),
      'https://api.example.test/kcc/v1/saints?q=%ED%94%84%EB%9E%80%EC%B9%98%EC%8A%A4%EC%BD%94&limit=30',
    );
    expect(
      source.searchUri('프란치스코', limit: 30, offset: 30).toString(),
      'https://api.example.test/kcc/v1/saints?q=%ED%94%84%EB%9E%80%EC%B9%98%EC%8A%A4%EC%BD%94&limit=30&offset=30',
    );
  });

  test('parses paged saint search responses', () async {
    final source = SaintSource(
      baseUrl: 'https://api.example.test/kcc/v1',
      client: MockClient((request) async {
        expect(request.url.queryParameters['q'], '프란치스코');
        expect(request.url.queryParameters['limit'], '30');
        expect(request.url.queryParameters['offset'], '30');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'total': 42,
              'limit': 30,
              'offset': 30,
              'hasMore': false,
              'nextOffset': 42,
              'items': [
                {
                  'id': 2855,
                  'nameKo': '프란치스코',
                  'nameLatin': 'Francis',
                  'feastMonth': 10,
                  'feastDay': 4,
                  'status': '부제, 설립자, 증거자',
                  'kind': '성인',
                  'regionKo': '아시시',
                  'regionEn': 'Assisi',
                  'yearText': '+1226년',
                  'url': 'https://example.test/saint/2855',
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await source.searchPage('프란치스코', limit: 30, offset: 30);

    expect(result.total, 42);
    expect(result.hasMore, isFalse);
    expect(result.nextOffset, 42);
    expect(result.items.single.nameKo, '프란치스코');
    expect(result.items.single.regionKo, '아시시');
  });
}
