import 'package:shared_preferences/shared_preferences.dart';

/// 개인 데이터 백업 관련 SharedPreferences 키와 시각 파서.
///
/// 자동 백업(변경마다 저장)은 사용하지 않는다. 사용자가 직접 백업하며,
/// 마지막 백업 후 10일이 지나면 알림을 띄운다. 시각은 UTC ISO8601로 저장한다.
class BackupPrefs {
  BackupPrefs._();

  /// 마지막으로 성공한 백업 시각(UTC ISO8601).
  static const String lastBackupAtKey = 'personal_backup_last_at';

  /// 백업 알림을 마지막으로 평가/표시한 시각(UTC ISO8601). 최초엔 데이터가
  /// 생긴 뒤 이 값을 심어, 첫 알림이 약 10일 후에 뜨도록 한다.
  static const String reminderAtKey = 'personal_backup_reminder_at';

  /// [key]에 저장된 시각을 파싱한다. 없거나 형식이 틀리면 null.
  static DateTime? readInstant(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// [key]에 [now]를 UTC ISO8601로 저장한다.
  static Future<void> writeNow(
    SharedPreferences prefs,
    String key,
    DateTime now,
  ) => prefs.setString(key, now.toUtc().toIso8601String());
}
