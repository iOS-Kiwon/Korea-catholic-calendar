import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app_update/app_update_service.dart';

const kDefaultFeastGiftShopUrl = 'https://m.smartstore.naver.com/amoondal';

final appMetadataProvider = FutureProvider<AppMetadata>((ref) {
  return const AppMetadataService().fetch();
});

class AppMetadata {
  const AppMetadata({required this.feastGiftShopUrl});

  final String feastGiftShopUrl;

  factory AppMetadata.fromJson(Map<String, dynamic> json) {
    final giftShop = json['giftShop'] as Map<String, dynamic>? ?? const {};
    final url = giftShop['url'] as String? ?? '';
    return AppMetadata(
      feastGiftShopUrl: _safeHttpUrl(url) ?? kDefaultFeastGiftShopUrl,
    );
  }

  static const fallback = AppMetadata(
    feastGiftShopUrl: kDefaultFeastGiftShopUrl,
  );
}

class AppMetadataService {
  const AppMetadataService({
    http.Client? client,
    this.baseUrl = kAppUpdateApiBaseUrl,
  }) : _client = client;

  final http.Client? _client;
  final String baseUrl;

  Future<AppMetadata> fetch() async {
    if (kIsWeb || baseUrl.isEmpty) return AppMetadata.fallback;

    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/app/metadata',
    );
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return AppMetadata.fallback;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return AppMetadata.fallback;
      return AppMetadata.fromJson(json);
    } catch (_) {
      return AppMetadata.fallback;
    } finally {
      if (_client == null) client.close();
    }
  }
}

String? _safeHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri.toString();
}
