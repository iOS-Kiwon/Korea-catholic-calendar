// 위젯 스냅샷 동기화 스로틀: 첫 요청은 즉시, 쿨다운 중 몰린 요청은 마지막에 1회.
//
// 이 동작이 중요한 이유: 스냅샷 생성은 ±12개월 × 42일치를 매번 다시 만드는 동기
// 작업이라(일정 200건 기준 데스크톱 약 380ms) 호출을 합쳐야 한다. 그러면서도 첫
// 요청은 늦출 수 없다 - 사용자가 일정을 저장하고 곧바로 홈으로 나가면 트레일링
// 타이머가 못 돌아 위젯이 안 바뀔 수 있다.
import 'package:catholic_calendar/features/widgets/widget_sync_throttle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cooldown = Duration(milliseconds: 40);

  test('첫 요청은 즉시 실행된다', () {
    var calls = 0;
    final throttle = WidgetSyncThrottle(
      onSync: () => calls++,
      cooldown: cooldown,
    );
    addTearDown(throttle.dispose);

    throttle.request();
    expect(calls, 1);
  });

  test('쿨다운 중 몰린 요청은 끝난 뒤 한 번만 더 실행된다', () async {
    var calls = 0;
    final throttle = WidgetSyncThrottle(
      onSync: () => calls++,
      cooldown: cooldown,
    );
    addTearDown(throttle.dispose);

    // 앱 시작 시 preloadAround(3개월) + eventStore가 연달아 발동하는 상황.
    for (var i = 0; i < 5; i++) {
      throttle.request();
    }
    expect(calls, 1, reason: '즉시 1회만 나가야 한다');
    expect(throttle.hasPending, isTrue);

    await Future<void>.delayed(cooldown * 2);
    expect(calls, 2, reason: '쿨다운 후 마지막 상태로 1회 더');
    expect(throttle.hasPending, isFalse);

    // 트레일링 실행이 새 쿨다운을 열고, 그 안에 요청이 없으면 더 나가지 않는다.
    await Future<void>.delayed(cooldown * 2);
    expect(calls, 2);
    expect(throttle.isCoolingDown, isFalse);
  });

  test('쿨다운이 끝난 뒤의 요청은 다시 즉시 실행된다', () async {
    var calls = 0;
    final throttle = WidgetSyncThrottle(
      onSync: () => calls++,
      cooldown: cooldown,
    );
    addTearDown(throttle.dispose);

    throttle.request();
    expect(calls, 1);

    await Future<void>.delayed(cooldown * 2);
    expect(calls, 1, reason: '대기 중인 요청이 없으면 추가 실행 없음');

    throttle.request();
    expect(calls, 2, reason: '저장할 때마다 지연 없이 위젯이 갱신돼야 한다');
  });

  test('dispose하면 대기 중인 트레일링 실행이 취소된다', () async {
    var calls = 0;
    final throttle = WidgetSyncThrottle(
      onSync: () => calls++,
      cooldown: cooldown,
    );

    throttle.request();
    throttle.request();
    expect(throttle.hasPending, isTrue);

    throttle.dispose();
    await Future<void>.delayed(cooldown * 2);
    expect(calls, 1);
  });
}
