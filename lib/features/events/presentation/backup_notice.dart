import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/category_providers.dart';
import '../application/event_providers.dart';
import '../data/category_repository.dart';
import '../data/event_repository.dart';
import '../data/personal_cloud_backup_store.dart';

/// Shown-once flag for the first personal-data backup notice.
const kBackupNoticeShownKey = 'backup_notice_shown_v1';
const kBackupRestoreNoticeShownKey = 'backup_restore_notice_shown_v1';

/// On a fresh install, quietly looks for an existing iCloud/Google Drive backup
/// and asks before restoring it. It only runs when the local personal data is
/// empty, so it does not risk overwriting an active install.
Future<void> maybeShowBackupRestoreNotice(
  BuildContext context,
  WidgetRef ref,
) async {
  final prefs = await ref.read(sharedPreferencesProvider.future);
  if (prefs.getBool(kBackupRestoreNoticeShownKey) ?? false) return;

  final hasLocalEvents = EventRepository(prefs).load().isNotEmpty;
  final hasLocalCategories = CategoryRepository(prefs).load().isNotEmpty;
  if (hasLocalEvents || hasLocalCategories) return;

  final controller = ref.read(personalCloudBackupControllerProvider);
  final snapshot = await controller.findRestorableSnapshot(
    includeSilentGoogleDriveProbe: true,
  );
  if (snapshot == null) return;

  await prefs.setBool(kBackupRestoreNoticeShownKey, true);
  if (!context.mounted) return;

  final eventCount = snapshot.events.values.fold<int>(
    0,
    (sum, events) => sum + events.length,
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('백업된 일정이 있어요'),
        content: Text(
          '이전에 저장된 일정 $eventCount개를 찾았습니다.\n'
          '이 기기에 복원할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final restored = await controller.restoreSnapshot(
                snapshot,
                enableGoogleDriveBackup: true,
              );
              if (!context.mounted) return;
              if (restored) {
                ref.invalidate(categoriesProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('백업된 일정을 복원했습니다.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('복원하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
                );
              }
            },
            child: const Text('복원하기'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      );
    },
  );
}

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
        '추가한 일정과 카테고리는 설정 > 백업에서 $service에 저장하고, '
        '앱을 다시 설치하거나 기기를 바꿔도 복원할 수 있어요.';
  } else if (isIos) {
    message =
        '설정 > 백업에서 iCloud에 일정과 카테고리를 저장하고 복원할 수 있어요.\n\n'
        '현재 iCloud가 켜져 있지 않아 지금은 백업할 수 없어요. '
        '설정 앱에서 "Apple 계정 > iCloud"를 켜 주세요.';
  } else {
    message =
        'Google Drive를 연동하면\n'
        '일정과 카테고리를 저장하고\n'
        '복원할 수 있어요.\n\n'
        '연동하시겠습니까?';
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
                if (!context.mounted) return;
                if (ok) {
                  await ref
                      .read(personalCloudBackupControllerProvider)
                      .backupNow(promptIfNeeded: true);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google Drive 연동을 완료했습니다.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isIos
                            ? 'iCloud 설정을 확인한 뒤 다시 시도해 주세요.'
                            : 'Google Drive 연동을 완료하지 못했습니다. Google 계정 설정을 확인해 주세요.',
                      ),
                    ),
                  );
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
