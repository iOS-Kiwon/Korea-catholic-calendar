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
  const AppMetadata({
    required this.feastGiftShopUrl,
    this.reviewPromptEnabled = true,
  });

  final String feastGiftShopUrl;

  /// 앱스토어 리뷰 요청 킬스위치. 서버가 값을 안 내려주거나 형식이 틀리면
  /// 켜진 것으로 본다(서버 장애가 기능을 죽이지 않게).
  final bool reviewPromptEnabled;

  factory AppMetadata.fromJson(Map<String, dynamic> json) {
    final giftShop = json['giftShop'] as Map<String, dynamic>? ?? const {};
    final url = giftShop['url'] as String? ?? '';
    final review = json['review'] as Map<String, dynamic>? ?? const {};
    // `as bool?`가 아니라 `is bool`로 본다. 잘못된 타입을 캐스트하면 예외가
    // 나서, 킬스위치 오타 하나가 메타데이터 전체를 fallback으로 떨어뜨린다.
    final reviewEnabled = review['enabled'];
    return AppMetadata(
      feastGiftShopUrl: _safeHttpUrl(url) ?? kDefaultFeastGiftShopUrl,
      reviewPromptEnabled: reviewEnabled is bool ? reviewEnabled : true,
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
