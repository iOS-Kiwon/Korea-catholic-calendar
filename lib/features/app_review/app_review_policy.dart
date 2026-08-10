import '../events/model/calendar_event.dart';

/// 리뷰를 요청하기 위해 필요한 최소 일정 개수.
///
/// 일정을 이만큼 채웠다는 것 자체를 "앱을 실제로 쓰고 있다"는 신호로 본다.
/// 설치 경과일이나 앱 실행 횟수는 보지 않는다.
const int kReviewMinEventCount = 5;

/// 리뷰 요청을 시도한 시각(UTC ISO8601). 값이 있으면 이 설치에서는 다시
/// 요청하지 않는다. 앱을 지우면 함께 사라지므로 재설치 시에는 다시 요청한다.
const String kReviewRequestedAtKey = 'review_requested_at';

/// OS 리뷰창을 요청할지 판정한다.
///
/// 시간 조건이 없으므로 현재 시각을 받지 않는다. 플랫폼 판별(`kIsWeb`)은
/// 호출부가 담당한다.
bool shouldRequestReview({
  required bool remoteEnabled,
  required DateTime? requestedAt,
  required int eventCount,
}) {
  if (requestedAt != null) return false; // 설치당 1회
  if (!remoteEnabled) return false; // 서버 킬스위치
  return eventCount >= kReviewMinEventCount;
}

/// 날짜별 일정 맵에 담긴 전체 일정 수.
///
/// 반복 일정은 저장된 엔트리가 하나이므로 회차 수와 무관하게 1개로 센다.
int countStoredEvents(Map<String, List<CalendarEvent>> events) =>
    events.values.fold<int>(0, (sum, list) => sum + list.length);
