import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_update/app_update_providers.dart';
import '../../app_update/app_update_service.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/personal_cloud_backup_store.dart';
import 'backup_settings_page.dart';

const String kPrivacyPolicyUrl = 'https://sidore.org/catholic-calendar-privacy';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(_backupAvailabilityProvider);
    final showBackup = availabilityAsync.maybeWhen(
      data: (a) => a != CloudBackupAvailability.unsupported,
      orElse: () => !kIsWeb,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('설정'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                if (showBackup) ...[
                  const _SectionLabel('백업'),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF2E7D32),
                      ),
                      title: Text(_isIos ? 'iCloud 백업' : 'Google 백업'),
                      subtitle: Text(
                        _isIos
                            ? 'iCloud에 일정을 백업하고 복원합니다'
                            : 'Google Drive에 일정을 백업하고 복원합니다',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BackupSettingsPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const _SectionLabel('약관 및 정책'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('개인정보 처리방침'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openUrl(kPrivacyPolicyUrl),
                  ),
                ),
              ],
            ),
          ),
          const _VersionFooter(),
        ],
      ),
    );
  }
}

/// 백업 섹션 노출 여부 판단용(설정 화면 한정). 실패 시 웹이 아니면 노출.
final _backupAvailabilityProvider = FutureProvider<CloudBackupAvailability>(
  (ref) => ref.read(personalCloudBackupStoreProvider).checkAvailability(),
);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _VersionFooter extends ConsumerWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final updateAvailable = ref.watch(appUpdateAvailableProvider).value ?? false;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (info == null) return const SizedBox(height: 24);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.appName.isEmpty ? '가톨릭 달력' : info.appName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '버전 ${info.version} (빌드 ${info.buildNumber})',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (updateAvailable) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => AppUpdateService.openStore(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '새로운 기능을 만나보세요 >',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
