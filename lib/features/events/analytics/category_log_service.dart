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
      await firestore.collection('category_stats').doc(categoryKey).set({
        'name': trimmed,
        'normalizedName': _normalizedName(trimmed),
        'lastColor': color,
        'count': FieldValue.increment(1),
        // 중첩 맵 + merge로 플랫폼별 카운터만 증가시킨다(다른 플랫폼 값 보존).
        // (점 표기 키를 set()에 쓰면 중첩이 아니라 'platformCounts.ios' 리터럴
        //  필드가 만들어지므로 사용하지 않는다.)
        'platformCounts': {_platformName(): FieldValue.increment(1)},
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
