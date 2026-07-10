import 'dart:convert';

import 'package:http/http.dart' as http;

import 'calendar_service.dart';

/// 전례력 캐시 게이트웨이(Cloudflare Worker) 기본 주소.
const kRemoteBaseUrl = 'https://catholic-calendar.sidore.workers.dev';

/// Fetches authoritative month data from the caching gateway.
///
/// Returns the parsed day map, or `null` when the month is unavailable
/// (미발행/네트워크 오류) so callers fall back to the bundled snapshot + engine.
class RemoteCalendarSource {
  const RemoteCalendarSource({
    this.baseUrl = kRemoteBaseUrl,
    this.enabled = true,
  });

  final String baseUrl;
  final bool enabled; // 테스트/오프라인에서 비활성화 가능

  Future<Map<String, CbckDay>?> fetchMonth(int year, int month) async {
    if (!enabled || baseUrl.isEmpty) return null;
    try {
      final uri = Uri.parse('$baseUrl/v1/calendar/$year/$month');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final doc =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (doc['available'] != true) return null;
      return CalendarService.parseDays(doc['days'] as List? ?? const []);
    } catch (_) {
      return null; // 오프라인/오류 → 폴백
    }
  }
}
