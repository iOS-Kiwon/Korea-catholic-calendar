import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_metadata/app_metadata_service.dart';
import '../events/application/event_providers.dart';
import 'app_review_policy.dart';

final appReviewServiceProvider = Provider<AppReviewService>(
  AppReviewService.new,
);

/// OS 네이티브 리뷰창을 조건부로 1회 요청한다.
///
/// 일정 저장 직후에만 호출한다(`showEventEditor`). 앱 시작 시점에는 띄우지
/// 않는다 - 앱을 열어보기만 한 사용자에게 리뷰를 청하지 않기 위해서다.
class AppReviewService {
  AppReviewService(this._ref, {InAppReview? review}) : _review = review;

  final Ref _ref;
  final InAppReview? _review;

  /// provider에서 값을 모아 [runWith]에 넘기는 얇은 어댑터.
  Future<void> maybeRequest() async {
    if (kIsWeb) return;

    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final metadata = await _ref.read(appMetadataProvider.future);
    final events = await _ref.read(eventStoreProvider.future);

    final requested = await runWith(
      prefs: prefs,
      remoteEnabled: metadata.reviewPromptEnabled,
      eventCount: countStoredEvents(events),
    );

    // 이 이벤트는 "요청 시도" 수다. 리뷰창이 실제로 떴는지, 사용자가 별점을
    // 매겼는지는 OS가 알려주지 않아 측정할 수 없다.
    if (requested && Firebase.apps.isNotEmpty) {
      await FirebaseAnalytics.instance.logEvent(name: 'app_review_requested');
    }
  }

  /// 판정 → 요청 → 기록. 실제로 요청을 보냈으면 true.
  ///
  /// provider에 의존하지 않아 단위 테스트에서 직접 호출한다.
  @visibleForTesting
  Future<bool> runWith({
    required SharedPreferences prefs,
    required bool remoteEnabled,
    required int eventCount,
  }) async {
    final raw = prefs.getString(kReviewRequestedAtKey);
    final requestedAt = (raw == null || raw.isEmpty)
        ? null
        : DateTime.tryParse(raw);

    if (!shouldRequestReview(
      remoteEnabled: remoteEnabled,
      requestedAt: requestedAt,
      eventCount: eventCount,
    )) {
      return false;
    }

    final review = _review ?? InAppReview.instance;
    try {
      // 띄울 수 없는 상황이면 기록을 남기지 않는다. 설치당 1회뿐인 기회를
      // 리뷰창이 뜨지 못한 상황에 소모하면 안 된다.
      if (!await review.isAvailable()) return false;
      await review.requestReview();
    } catch (error) {
      debugPrint('[KCC review] 리뷰 요청 실패: $error');
      return false;
    }

    await prefs.setString(
      kReviewRequestedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    return true;
  }
}
