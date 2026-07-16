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
      await firestore.collection('category_add_logs').add({
        'name': trimmed,
        'color': color,
        'platform': _platformName(),
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
}

class NoopCategoryLogService implements CategoryLogService {
  const NoopCategoryLogService();

  @override
  Future<void> logCategoryAdded({
    required String name,
    required int color,
  }) async {}
}
