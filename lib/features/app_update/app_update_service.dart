import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const kAppUpdateApiBaseUrl = String.fromEnvironment(
  'KCC_API_BASE_URL',
  defaultValue: 'https://api.sidore.org/kcc/v1',
);

const _iosAppStoreUrl = 'https://apps.apple.com/app/id6791044471';
const _androidPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sidore.catholiccalendar';

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.dialogType,
    required this.title,
    required this.message,
  });

  final String dialogType;
  final String title;
  final String message;

  bool get isForceUpdate => dialogType == 'forceUpdate';
  bool get isRecommendedUpdate => dialogType == 'recommendedUpdate';
  bool get shouldShow => isForceUpdate || isRecommendedUpdate;

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) {
    final dialog = json['dialog'] as Map<String, dynamic>? ?? const {};
    return AppUpdatePolicy(
      dialogType: dialog['type'] as String? ?? 'none',
      title: dialog['title'] as String? ?? '',
      message: dialog['message'] as String? ?? '',
    );
  }
}

class AppUpdateService {
  const AppUpdateService({
    http.Client? client,
    this.baseUrl = kAppUpdateApiBaseUrl,
  }) : _client = client;

  final http.Client? _client;
  final String baseUrl;

  Future<AppUpdatePolicy?> check() async {
    final platform = _platformName();
    if (platform == null || baseUrl.isEmpty) return null;

    final info = await PackageInfo.fromPlatform();
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/app/version',
    ).replace(queryParameters: {'platform': platform, 'version': info.version});

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return null;
      final policy = AppUpdatePolicy.fromJson(json);
      return policy.shouldShow ? policy : null;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  static Uri? storeUri() {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse(_iosAppStoreUrl);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse(_androidPlayStoreUrl);
    }
    return null;
  }

  static Future<void> openStore() async {
    final uri = storeUri();
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String? _platformName() {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return null;
  }
}
