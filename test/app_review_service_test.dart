import 'package:catholic_calendar/features/app_review/app_review_policy.dart';
import 'package:catholic_calendar/features/app_review/app_review_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `openStoreListing` 등 우리가 쓰지 않는 멤버는 noSuchMethod로 넘긴다.
/// 이렇게 하면 패키지가 메서드를 추가해도 이 fake가 깨지지 않는다.
class _FakeInAppReview implements InAppReview {
  _FakeInAppReview({this.available = true, this.throwOnRequest = false});

  final bool available;
  final bool throwOnRequest;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    if (throwOnRequest) throw Exception('platform channel unavailable');
    requestCount += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AppReviewService, _FakeInAppReview, SharedPreferences)> setUpService({
    bool available = true,
    bool throwOnRequest = false,
  }) async {
    final review = _FakeInAppReview(
      available: available,
      throwOnRequest: throwOnRequest,
    );
    final container = ProviderContainer(
      overrides: [
        appReviewServiceProvider.overrideWith(
          (ref) => AppReviewService(ref, review: review),
        ),
      ],
    );
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    return (container.read(appReviewServiceProvider), review, prefs);
  }

  test('조건을 만족하면 리뷰를 요청하고 시각을 기록한다', () async {
    final (service, review, prefs) = await setUpService();

    final requested = await service.runWith(
      prefs: prefs,
      remoteEnabled: true,
      eventCount: 5,
    );

    expect(requested, isTrue);
    expect(review.requestCount, 1);
    expect(prefs.getString(kReviewRequestedAtKey), isNotNull);
  });

  test('일정이 모자라면 요청하지도, 기록하지도 않는다', () async {
    final (service, review, prefs) = await setUpService();

    final requested = await service.runWith(
      prefs: prefs,
      remoteEnabled: true,
      eventCount: 4,
    );

    expect(requested, isFalse);
    expect(review.requestCount, 0);
    expect(prefs.getString(kReviewRequestedAtKey), isNull);
  });

  test('이미 요청한 뒤에는 다시 요청하지 않는다', () async {
    final (service, review, prefs) = await setUpService();
    await prefs.setString(
      kReviewRequestedAtKey,
      DateTime.utc(2026, 8, 1).toIso8601String(),
    );

    final requested = await service.runWith(
      prefs: prefs,
      remoteEnabled: true,
      eventCount: 10,
    );

    expect(requested, isFalse);
    expect(review.requestCount, 0);
  });

  test('킬스위치가 꺼져 있으면 요청하지 않는다', () async {
    final (service, review, prefs) = await setUpService();

    final requested = await service.runWith(
      prefs: prefs,
      remoteEnabled: false,
      eventCount: 10,
    );

    expect(requested, isFalse);
    expect(review.requestCount, 0);
  });

  test('리뷰창을 띄울 수 없으면 기록을 남기지 않는다', () async {
    final (service, review, prefs) = await setUpService(available: false);

    final requested = await service.runWith(
      prefs: prefs,
      remoteEnabled: true,
      eventCount: 10,
    );

    expect(requested, isFalse);
    expect(review.requestCount, 0);
    // 설치당 1회뿐인 기회를 못 띄운 상황에 소모하지 않는다.
    expect(prefs.getString(kReviewRequestedAtKey), isNull);
  });

  test('요청이 예외를 던지면 기록하지 않고 삼킨다', () async {
    final (service, _, prefs) = await setUpService(throwOnRequest: true);

    final requested = await service.runWith(
      prefs: prefs,
      remoteEnabled: true,
      eventCount: 10,
    );

    expect(requested, isFalse);
    expect(prefs.getString(kReviewRequestedAtKey), isNull);
  });
}
