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
    required this.updateMode,
    required this.updateVersion,
  });

  final String dialogType;
  final String title;
  final String message;
  final String updateMode;
  final String updateVersion;

  bool get isForceUpdate => dialogType == 'forceUpdate';
  bool get isRecommendedUpdate => dialogType == 'recommendedUpdate';
  bool get shouldShow => isForceUpdate || isRecommendedUpdate;

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) {
    final dialog = json['dialog'] as Map<String, dynamic>? ?? const {};
    final currentVersion = json['currentVersion'] as String? ?? '';
    final updateVersion = json['updateVersion'] as String? ?? '';
    final rawDialogType = dialog['type'] as String? ?? 'none';
    final dialogType =
        _versionAllowsDialog(currentVersion, updateVersion, rawDialogType)
        ? rawDialogType
        : 'none';
    return AppUpdatePolicy(
      dialogType: dialogType,
      title: dialog['title'] as String? ?? '',
      message: dialog['message'] as String? ?? '',
      updateMode: json['updateMode'] as String? ?? 'none',
      updateVersion: updateVersion,
    );
  }
}

bool _versionAllowsDialog(
  String currentVersion,
  String updateVersion,
  String dialogType,
) {
  if (dialogType != 'forceUpdate' && dialogType != 'recommendedUpdate') {
    return false;
  }
  if (!_isSemanticVersion(currentVersion) ||
      !_isSemanticVersion(updateVersion)) {
    return true;
  }
  return _compareSemanticVersions(currentVersion, updateVersion) < 0;
}

bool _isSemanticVersion(String value) =>
    RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value);

int _compareSemanticVersions(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  for (var index = 0; index < 3; index += 1) {
    if (leftParts[index] < rightParts[index]) return -1;
    if (leftParts[index] > rightParts[index]) return 1;
  }
  return 0;
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
