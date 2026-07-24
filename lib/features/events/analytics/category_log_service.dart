import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract class CategoryLogService {
  Future<void> logCategoryAdded({required String name, required int color});
}

final categoryLogServiceProvider = Provider<CategoryLogService>(
  (ref) => FirestoreCategoryLogService(),
);

class FirestoreCategoryLogService implements CategoryLogService {
  FirestoreCategoryLogService({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  @override
  Future<void> logCategoryAdded({
    required String name,
    required int color,
  }) async {
    final trimmed = name.trim();
    if (!kReleaseMode || trimmed.isEmpty || Firebase.apps.isEmpty) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final firestore = _firestore ?? FirebaseFirestore.instance;
      final categoryKey = _categoryKey(trimmed);
      await firestore.collection('category_add_logs').add({
        'categoryKey': categoryKey,
        'name': trimmed,
        'normalizedName': _normalizedName(trimmed),
        'color': color,
        'platform': _platformName(),
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // 목적: '어떤 카테고리 이름을 많이 쓰는지' 집계해 인기 카테고리를 기본값으로
      // 제공하기 위함. 이름별(normalizedName) 문서 1개에 count를 누적한다.
      // 플랫폼별 분포는 필요 없어 저장하지 않는다.
      await firestore.collection('category_stats').doc(categoryKey).set({
        'name': trimmed,
        'normalizedName': _normalizedName(trimmed),
        'lastColor': color,
        'count': FieldValue.increment(1),
        'lastAddedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to log category add: $e');
      }
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }

  String _normalizedName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String _categoryKey(String value) =>
      base64Url.encode(utf8.encode(_normalizedName(value))).replaceAll('=', '');
}

class NoopCategoryLogService implements CategoryLogService {
  const NoopCategoryLogService();

  @override
  Future<void> logCategoryAdded({
    required String name,
    required int color,
  }) async {}
}
