import 'package:catholic_calendar/features/events/presentation/backup_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 23);

  test('데이터가 없으면 알림 안 함', () {
    expect(
      shouldShowBackupReminder(now: now, hasData: false, reminderAt: now.subtract(const Duration(days: 30))),
      isFalse,
    );
  });

  test('기준 시각이 없으면(첫 평가) 알림 안 함', () {
    expect(
      shouldShowBackupReminder(now: now, hasData: true),
      isFalse,
    );
  });

  test('마지막 백업 후 10일 미만이면 알림 안 함', () {
    expect(
      shouldShowBackupReminder(now: now, hasData: true, lastBackupAt: now.subtract(const Duration(days: 9))),
      isFalse,
    );
  });

  test('마지막 백업 후 10일 이상이면 알림', () {
    expect(
      shouldShowBackupReminder(now: now, hasData: true, lastBackupAt: now.subtract(const Duration(days: 10))),
      isTrue,
    );
  });

  test('백업 이력이 없고 reminderAt 기준 10일 지나면 알림', () {
    expect(
      shouldShowBackupReminder(now: now, hasData: true, reminderAt: now.subtract(const Duration(days: 11))),
      isTrue,
    );
  });

  test('lastBackupAt이 reminderAt보다 최근이면 그 기준으로 판단', () {
    expect(
      shouldShowBackupReminder(
        now: now,
        hasData: true,
        lastBackupAt: now.subtract(const Duration(days: 2)),
        reminderAt: now.subtract(const Duration(days: 30)),
      ),
      isFalse,
    );
  });

  test('스누즈: reminderAt이 lastBackupAt보다 최근이면 억제(재노출 안 함)', () {
    expect(
      shouldShowBackupReminder(
        now: now,
        hasData: true,
        lastBackupAt: now.subtract(const Duration(days: 30)),
        reminderAt: now.subtract(const Duration(days: 1)),
      ),
      isFalse,
    );
  });

  test('reminderAt 단독 기준 정확히 10일 경계면 알림', () {
    expect(
      shouldShowBackupReminder(
        now: now,
        hasData: true,
        reminderAt: now.subtract(const Duration(days: 10)),
      ),
      isTrue,
    );
  });
}
