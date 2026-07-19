import 'dart:convert';

import 'package:http/http.dart' as http;

import 'calendar_service.dart';

/// Self-hosted KCC API base URL.
///
/// Override for local testing, for example:
/// `--dart-define=KCC_API_BASE_URL=http://127.0.0.1:18080/kcc/v1`.
const kRemoteBaseUrl = String.fromEnvironment(
  'KCC_API_BASE_URL',
  defaultValue: 'https://api.sidore.org/kcc/v1',
);

/// Fetches authoritative month data from the self-hosted KCC API.
///
/// Returns the parsed day map, or `null` when the month is unavailable
/// (미발행/네트워크 오류) so callers fall back to the bundled snapshot + engine.
class RemoteCalendarSource {
  const RemoteCalendarSource({
    this.baseUrl = kRemoteBaseUrl,
    this.enabled = true,
    this.client,
  });

  final String baseUrl;
  final bool enabled; // 테스트/오프라인에서 비활성화 가능
  final http.Client? client;

  Uri monthUri(int year, int month) => Uri.parse(
    '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/calendar/$year/$month',
  );

  Future<Map<String, CbckDay>?> fetchMonth(int year, int month) async {
    if (!enabled || baseUrl.isEmpty) return null;
    final activeClient = client ?? http.Client();
    try {
      final res = await activeClient
          .get(monthUri(year, month))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final doc =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (doc['available'] != true) return null;
      return CalendarService.parseDays(doc['days'] as List? ?? const []);
    } catch (_) {
      return null; // 오프라인/오류 → 폴백
    } finally {
      if (client == null) activeClient.close();
    }
  }
}
