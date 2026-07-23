import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/backup_settings_page.dart';
import '../application/event_providers.dart';
import '../data/backup_prefs.dart';

/// 마지막 백업(또는 알림 기준) 이후 [threshold]가 지났고 보호할 데이터가 있으면 true.
///
/// 기준(baseline)은 마지막 백업 시각과 마지막 알림 시각 중 더 최근 시각.
/// 둘 다 없으면(최초) false - 호출부가 reminderAt을 심어 다음부터 카운트한다.
bool shouldShowBackupReminder({
  required DateTime now,
  required bool hasData,
  DateTime? lastBackupAt,
  DateTime? reminderAt,
  Duration threshold = const Duration(days: 10),
}) {
  if (!hasData) return false;
  final baseline = _latest(lastBackupAt, reminderAt);
  if (baseline == null) return false;
  return now.difference(baseline) >= threshold;
}

/// [a], [b] 중 더 최근(늦은) 시각을 반환한다. null은 "값 없음"으로 취급한다.
DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// 앱 콜드 스타트 시 1회 평가하는 백업 알림. 조건 충족 시 팝업을 띄우고,
/// "확인"을 누르면 백업 화면으로 이동한다(팝업이 직접 백업하지 않음).
Future<void> maybeShowBackupReminder(
  BuildContext context,
  WidgetRef ref,
) async {
  if (kIsWeb) return;

  final prefs = await ref.read(sharedPreferencesProvider.future);
  final events = await ref.read(eventStoreProvider.future);
  final hasData = events.isNotEmpty;
  if (!hasData) return;

  final now = DateTime.now();
  final lastBackupAt = BackupPrefs.readInstant(prefs, BackupPrefs.lastBackupAtKey);
  final reminderAt = BackupPrefs.readInstant(prefs, BackupPrefs.reminderAtKey);

  // 최초: 백업/알림 이력이 없으면 기준 시각만 심고 이번엔 표시하지 않는다.
  if (lastBackupAt == null && reminderAt == null) {
    await BackupPrefs.writeNow(prefs, BackupPrefs.reminderAtKey, now);
    return;
  }

  if (!shouldShowBackupReminder(
    now: now,
    hasData: hasData,
    lastBackupAt: lastBackupAt,
    reminderAt: reminderAt,
  )) {
    return;
  }

  // 표시 여부와 무관하게 스누즈(최소 10일 간격 재노출).
  await BackupPrefs.writeNow(prefs, BackupPrefs.reminderAtKey, now);
  if (!context.mounted) return;

  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('백업이 필요해요'),
      content: const Text('마지막 백업 후 10일이 지났어요. 지금 백업할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  if (go == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BackupSettingsPage()),
    );
  }
}
