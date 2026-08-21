import 'dart:async';

/// 홈 위젯 스냅샷 동기화 요청을 합친다(leading-edge 스로틀 + 트레일링 1회).
///
/// 스냅샷 생성은 ±12개월 × 42일치를 매번 다시 만들어 400KB가 넘는 JSON을 뽑는
/// 동기 작업이다(일정 200건 기준 데스크톱 약 380ms, 실기기는 더 느리다). 그런데
/// 호출은 몰려서 들어온다 - `preloadAround`가 3개월을 병렬로 불러오고 `ensureMonth`가
/// 원격 병합마다 `state = AsyncData(service)`를 하므로 앱 시작·월 이동 때 연달아
/// 여러 번 발동한다.
///
/// 그래서 첫 요청은 **즉시** 보내고, 쿨다운 동안 들어온 요청은 마지막에 한 번만 더
/// 보낸다. 트레일링만 쓰는 흔한 디바운스로 첫 요청까지 늦추면, 사용자가 일정을 저장한
/// 뒤 곧바로 홈으로 나갈 때 타이머가 못 돌아 위젯이 안 바뀔 수 있다.
class WidgetSyncThrottle {
  WidgetSyncThrottle({
    required this.onSync,
    this.cooldown = const Duration(milliseconds: 800),
  });

  final void Function() onSync;
  final Duration cooldown;

  Timer? _timer;
  bool _pending = false;

  /// 쿨다운 중인지(테스트/진단용).
  bool get isCoolingDown => _timer != null;

  /// 쿨다운이 끝나면 한 번 더 보낼 요청이 쌓여 있는지(테스트/진단용).
  bool get hasPending => _pending;

  void request() {
    if (_timer != null) {
      _pending = true;
      return;
    }
    _timer = Timer(cooldown, _onCooldownEnd);
    onSync();
  }

  void _onCooldownEnd() {
    _timer = null;
    if (!_pending) return;
    _pending = false;
    request();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = false;
  }
}
