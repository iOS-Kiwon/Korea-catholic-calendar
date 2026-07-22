import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../calendar/data/remote_calendar_source.dart';
import '../model/saint.dart';

class SaintSource {
  const SaintSource({this.baseUrl = kRemoteBaseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  Uri searchUri(String query) => Uri.parse(
    '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/saints',
  ).replace(queryParameters: {'q': query, 'limit': '30'});

  Future<List<Saint>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty || baseUrl.isEmpty) return const [];
    final activeClient = client ?? http.Client();
    try {
      final res = await activeClient
          .get(searchUri(q))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final doc =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final items = doc['items'] as List? ?? const [];
      return [
        for (final item in items) Saint.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    } finally {
      if (client == null) activeClient.close();
    }
  }
}
