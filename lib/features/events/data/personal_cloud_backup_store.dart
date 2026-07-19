import 'package:flutter/services.dart';

class PersonalCloudBackupStore {
  const PersonalCloudBackupStore({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.sidore.catholiccalendar/personal_backup');

  final MethodChannel _channel;

  Future<String?> loadSnapshotJson() async {
    try {
      final result = await _channel.invokeMethod<String>('loadSnapshot');
      if (result == null || result.isEmpty) return null;
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveSnapshotJson(String snapshotJson) async {
    try {
      final result = await _channel.invokeMethod<bool>('saveSnapshot', {
        'snapshotJson': snapshotJson,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
