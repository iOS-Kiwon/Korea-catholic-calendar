import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/event_providers.dart';
import '../data/personal_cloud_backup_store.dart';

/// Shown-once flag for the first personal-data backup notice.
const kBackupNoticeShownKey = 'backup_notice_shown_v1';

/// Shows a one-time notice, the first time the user finishes adding a personal
/// event, that their events/categories back up to iCloud (iOS) / Google Drive
/// (Android) and restore on reinstall. If cloud isn't set up yet, it guides the
/// user to enable it. No-op on web/desktop, and never shown more than once.
///
/// Trigger this right after a successful *add* (not on launch/restore).
Future<void> maybeShowBackupNotice(BuildContext context, WidgetRef ref) async {
  final prefs = await ref.read(sharedPreferencesProvider.future);
  if (prefs.getBool(kBackupNoticeShownKey) ?? false) return;

  final store = ref.read(personalCloudBackupStoreProvider);
  final availability = await store.checkAvailability();
  if (availability == CloudBackupAvailability.unsupported) return;

  await prefs.setBool(kBackupNoticeShownKey, true);
  if (!context.mounted) return;

  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  final service = isIos ? 'iCloud' : 'Google Drive';
  final configured = availability == CloudBackupAvailability.available;

  final String message;
  if (configured) {
    message =
        '추가한 일정과 카테고리는 이 기기의 $service에 자동으로 저장되고, '
        '앱을 다시 설치하거나 기기를 바꿔도 복원됩니다.';
  } else if (isIos) {
    message =
        '추가한 일정과 카테고리는 iCloud에 자동으로 저장·복원됩니다.\n\n'
        '현재 iCloud가 켜져 있지 않아 지금은 백업되지 않습니다. '
        '설정 앱에서 "Apple 계정 > iCloud"를 켜 주세요.';
  } else {
    message =
        '추가한 일정과 카테고리는 Google Drive에 자동으로 저장·복원됩니다.\n\n'
        '현재 Google 계정이 연동되어 있지 않아 지금은 백업되지 않습니다. '
        '아래에서 연동해 주세요.';
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      // 서브타이틀·버튼 폰트를 기본보다 2단계(+4) 키운다.
      final subtitleStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
          .copyWith(
            fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) + 4,
            height: 1.45,
            color: theme.colorScheme.onSurfaceVariant,
          );
      final buttonStyle = TextStyle(
        fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) + 4,
        fontWeight: FontWeight.w600,
      );

      Widget actions() {
        if (configured) {
          return Center(
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('확인', style: buttonStyle),
            ),
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('나중에', style: buttonStyle),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final ok = await store.promptSetup();
                if (ok) {
                  await ref
                      .read(personalCloudBackupControllerProvider)
                      .backupNow();
                }
              },
              child: Text(isIos ? '설정 열기' : '연동하기', style: buttonStyle),
            ),
          ],
        );
      }

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '내 일정 백업',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center, style: subtitleStyle),
              const SizedBox(height: 22),
              actions(),
            ],
          ),
        ),
      );
    },
  );
}
