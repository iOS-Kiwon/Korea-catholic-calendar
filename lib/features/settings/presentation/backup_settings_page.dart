import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/application/category_providers.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/backup_prefs.dart';
import '../../events/data/personal_cloud_backup_store.dart';

/// 백업 상태 확인 + 수동 백업/복원 + 설정 안내 화면.
class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  CloudBackupAvailability? _availability;
  DateTime? _lastBackupAt;
  bool _busy = false;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;
  String get _serviceName => _isIos ? 'iCloud' : 'Google Drive';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = ref.read(personalCloudBackupStoreProvider);
    final availability = await store.checkAvailability();
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _lastBackupAt = BackupPrefs.readInstant(prefs, BackupPrefs.lastBackupAtKey);
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setup() async {
    setState(() => _busy = true);
    final ok = await ref.read(personalCloudBackupStoreProvider).promptSetup();
    if (ok) await ref.read(personalCloudBackupControllerProvider).backupNow();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ok ? '$_serviceName 연동을 완료했습니다.' : '$_serviceName 설정을 확인한 뒤 다시 시도해 주세요.');
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    await ref.read(personalCloudBackupControllerProvider).backupNow();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack('백업했습니다.');
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('복원'),
        content: const Text('현재 기기의 일정/카테고리를 클라우드 백업으로 덮어씁니다(전체 교체). 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('복원'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final restored =
        await ref.read(personalCloudBackupControllerProvider).restoreIfAvailable();
    if (restored) ref.invalidate(categoriesProvider);
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(restored ? '복원했습니다.' : '복원할 백업이 없습니다.');
  }

  String _lastBackupLabel() {
    final at = _lastBackupAt;
    if (at == null) return '마지막 백업: 아직 없음';
    final days = DateTime.now().difference(at.toLocal()).inDays;
    return days <= 0 ? '마지막 백업: 오늘' : '마지막 백업: $days일 전';
  }

  @override
  Widget build(BuildContext context) {
    final availability = _availability;
    return Scaffold(
      appBar: AppBar(title: const Text('백업'), centerTitle: true),
      body: availability == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      availability == CloudBackupAvailability.available
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                    ),
                    title: Text(
                      availability == CloudBackupAvailability.available
                          ? '$_serviceName에 연결됨'
                          : '$_serviceName 백업 설정이 필요합니다',
                    ),
                    subtitle: availability == CloudBackupAvailability.available
                        ? Text(_lastBackupLabel())
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (availability == CloudBackupAvailability.available) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _backupNow,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('지금 백업'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('복원'),
                  ),
                ] else
                  FilledButton(
                    onPressed: _busy ? null : _setup,
                    child: const Text('설정하기'),
                  ),
              ],
            ),
    );
  }
}
