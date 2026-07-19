import 'package:catholic_calendar/features/app_update/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses force update dialog policy', () {
    final policy = AppUpdatePolicy.fromJson({
      'dialog': {
        'type': 'forceUpdate',
        'title': '업데이트가 필요합니다',
        'message': '최신 버전으로 업데이트해 주세요.',
        'actions': ['update'],
      },
    });

    expect(policy.isForceUpdate, isTrue);
    expect(policy.isRecommendedUpdate, isFalse);
    expect(policy.shouldShow, isTrue);
    expect(policy.title, '업데이트가 필요합니다');
  });

  test('parses recommended update dialog policy', () {
    final policy = AppUpdatePolicy.fromJson({
      'dialog': {
        'type': 'recommendedUpdate',
        'title': '새 버전이 있습니다',
        'message': '더 안정적인 버전을 사용할 수 있습니다.',
        'actions': ['later', 'update'],
      },
    });

    expect(policy.isForceUpdate, isFalse);
    expect(policy.isRecommendedUpdate, isTrue);
    expect(policy.shouldShow, isTrue);
  });

  test('does not show none dialog policy', () {
    final policy = AppUpdatePolicy.fromJson({
      'dialog': {'type': 'none', 'title': '', 'message': '', 'actions': []},
    });

    expect(policy.shouldShow, isFalse);
  });
}
