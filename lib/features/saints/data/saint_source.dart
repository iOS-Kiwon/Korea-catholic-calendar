import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../calendar/data/remote_calendar_source.dart';
import '../model/saint.dart';

class SaintSearchResult {
  const SaintSearchResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<Saint> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;
  final int nextOffset;
}

class SaintSource {
  const SaintSource({this.baseUrl = kRemoteBaseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  Uri searchUri(String query, {int limit = 30, int offset = 0}) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/saints').replace(
        queryParameters: {
          'q': query,
          'limit': '$limit',
          if (offset > 0) 'offset': '$offset',
        },
      );

  Future<List<Saint>> search(String query) async {
    final result = await searchPage(query);
    return result.items;
  }

  Future<SaintSearchResult> searchPage(
    String query, {
    int limit = 30,
    int offset = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty || baseUrl.isEmpty) {
      return SaintSearchResult(
        items: const [],
        total: 0,
        limit: limit,
        offset: offset,
        hasMore: false,
        nextOffset: offset,
      );
    }
    final activeClient = client ?? http.Client();
    try {
      final res = await activeClient
          .get(searchUri(q, limit: limit, offset: offset))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        return SaintSearchResult(
          items: const [],
          total: 0,
          limit: limit,
          offset: offset,
          hasMore: false,
          nextOffset: offset,
        );
      }
      final doc =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final items = doc['items'] as List? ?? const [];
      final saints = [
        for (final item in items) Saint.fromJson(item as Map<String, dynamic>),
      ];
      final total = (doc['total'] as num?)?.toInt() ?? saints.length;
      final nextOffset =
          (doc['nextOffset'] as num?)?.toInt() ?? offset + saints.length;
      return SaintSearchResult(
        items: saints,
        total: total,
        limit: (doc['limit'] as num?)?.toInt() ?? limit,
        offset: (doc['offset'] as num?)?.toInt() ?? offset,
        hasMore: doc['hasMore'] as bool? ?? nextOffset < total,
        nextOffset: nextOffset,
      );
    } catch (_) {
      return SaintSearchResult(
        items: const [],
        total: 0,
        limit: limit,
        offset: offset,
        hasMore: false,
        nextOffset: offset,
      );
    } finally {
      if (client == null) activeClient.close();
    }
  }
}
