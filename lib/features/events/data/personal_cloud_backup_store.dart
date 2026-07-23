import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Whether the platform's cloud backup destination (iCloud on iOS, Google
/// Drive on Android) is ready to store the user's personal data.
enum CloudBackupAvailability {
  /// Signed in and ready to back up.
  available,

  /// Supported platform, but the user has not set up iCloud/Google yet.
  notConfigured,

  /// No cloud backup on this platform (web/desktop).
  unsupported,
}

const kGoogleDriveBackupEnabledKey = 'google_drive_backup_enabled_v1';

class PersonalCloudBackupStore {
  const PersonalCloudBackupStore({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.sidore.catholiccalendar/personal_backup');

  final MethodChannel _channel;
  static const _googleConfigChannel = MethodChannel(
    'com.sidore.catholiccalendar/google_config',
  );
  static const _driveScopes = [drive.DriveApi.driveAppdataScope];
  static const _driveFileName = 'personalDataSnapshotV1.json';
  static Future<void>? _googleSignInInitialization;
  static GoogleSignInAccount? _activeGoogleAccount;

  /// Checks whether cloud backup is set up, without prompting the user.
  /// iOS → iCloud account present; Android → Google account active in this app
  /// session. Android does not silently sign in here, so backup setup only
  /// starts from an explicit user action.
  Future<CloudBackupAvailability> checkAvailability() async {
    if (kIsWeb) return CloudBackupAvailability.unsupported;
    if (_usesGoogleDriveBackup) {
      return _activeGoogleAccount == null
          ? CloudBackupAvailability.notConfigured
          : CloudBackupAvailability.available;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final ok = await _channel.invokeMethod<bool>('backupAvailability');
        return ok == true
            ? CloudBackupAvailability.available
            : CloudBackupAvailability.notConfigured;
      } on MissingPluginException {
        return CloudBackupAvailability.unsupported;
      } catch (_) {
        return CloudBackupAvailability.notConfigured;
      }
    }
    return CloudBackupAvailability.unsupported;
  }

  /// Guides the user to set up backup. Android → runs the Google sign-in/consent
  /// flow (returns true on success). iOS → opens the system Settings app (there
  /// is no public deep link to iCloud settings) and returns false.
  Future<bool> promptSetup() async {
    if (_usesGoogleDriveBackup) {
      debugPrint('[KCC backup] Starting Google Drive setup');
      final session = await _driveSession(promptIfNeeded: true);
      session?.close();
      final ok = session != null;
      debugPrint(
        '[KCC backup] Google Drive setup ${ok ? 'completed' : 'failed'}',
      );
      return ok;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _channel.invokeMethod('openSettings');
      } catch (_) {}
      return false;
    }
    return false;
  }

  Future<String?> loadSnapshotJson({
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async {
    if (_usesGoogleDriveBackup) {
      if (!promptIfNeeded && !allowSilentGoogleDrive) return null;
      return _loadGoogleDriveSnapshotJson();
    }

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

  Future<bool> saveSnapshotJson(
    String snapshotJson, {
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async {
    if (_usesGoogleDriveBackup) {
      if (!promptIfNeeded && !allowSilentGoogleDrive) return false;
      return _saveGoogleDriveSnapshotJson(
        snapshotJson,
        promptIfNeeded: promptIfNeeded,
      );
    }

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

  bool get _usesGoogleDriveBackup =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    final serverClientId = await _googleServerClientId();
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  }

  Future<String?> _googleServerClientId() async {
    if (!_usesGoogleDriveBackup) return null;
    try {
      final id = await _googleConfigChannel.invokeMethod<String>(
        'serverClientId',
      );
      if (id == null || id.isEmpty) {
        debugPrint('[KCC backup] Google serverClientId is empty');
        return null;
      }
      return id;
    } on MissingPluginException {
      debugPrint('[KCC backup] Google config channel is unavailable');
      return null;
    } on PlatformException catch (error) {
      debugPrint('[KCC backup] Google serverClientId load failed: $error');
      return null;
    }
  }

  Future<_GoogleDriveSession?> _driveSession({
    required bool promptIfNeeded,
  }) async {
    try {
      await _ensureGoogleSignInInitialized();

      final googleSignIn = GoogleSignIn.instance;
      GoogleSignInAccount? account = _activeGoogleAccount;

      if (account == null &&
          promptIfNeeded &&
          googleSignIn.supportsAuthenticate()) {
        account = await googleSignIn.authenticate(scopeHint: _driveScopes);
      }

      if (account == null) {
        debugPrint('[KCC backup] Google account is not active in this session');
        return null;
      }
      _activeGoogleAccount = account;

      final authorization =
          await account.authorizationClient.authorizationForScopes(
            _driveScopes,
          ) ??
          (promptIfNeeded
              ? await account.authorizationClient.authorizeScopes(_driveScopes)
              : null);
      if (authorization == null) {
        debugPrint(
          '[KCC backup] Google Drive scope authorization was not granted',
        );
        return null;
      }

      final authClient = authorization.authClient(scopes: _driveScopes);
      return _GoogleDriveSession(drive.DriveApi(authClient), authClient);
    } catch (error) {
      debugPrint('[KCC backup] Google Drive authorization failed: $error');
      return null;
    }
  }

  Future<String?> _loadGoogleDriveSnapshotJson() async {
    final session = await _driveSession(promptIfNeeded: false);
    if (session == null) return null;

    try {
      final file = await _findGoogleDriveBackupFile(session.api);
      if (file?.id == null) return null;

      final media =
          await session.api.files.get(
                file!.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      final result = utf8.decode(bytes);
      return result.isEmpty ? null : result;
    } catch (error) {
      debugPrint('[KCC backup] Google Drive backup load failed: $error');
      return null;
    } finally {
      session.close();
    }
  }

  Future<bool> _saveGoogleDriveSnapshotJson(
    String snapshotJson, {
    required bool promptIfNeeded,
  }) async {
    final session = await _driveSession(promptIfNeeded: promptIfNeeded);
    if (session == null) return false;

    try {
      final bytes = utf8.encode(snapshotJson);
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );
      final existingFile = await _findGoogleDriveBackupFile(session.api);
      if (existingFile?.id == null) {
        await session.api.files.create(
          drive.File()
            ..name = _driveFileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      } else {
        await session.api.files.update(
          drive.File()..name = _driveFileName,
          existingFile!.id!,
          uploadMedia: media,
        );
      }
      return true;
    } catch (error) {
      debugPrint('[KCC backup] Google Drive backup save failed: $error');
      return false;
    } finally {
      session.close();
    }
  }

  Future<drive.File?> _findGoogleDriveBackupFile(drive.DriveApi api) async {
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_driveFileName'",
      $fields: 'files(id, name, modifiedTime)',
      pageSize: 1,
    );
    final result = files.files;
    if (result == null || result.isEmpty) return null;
    return result.first;
  }
}

class _GoogleDriveSession {
  const _GoogleDriveSession(this.api, this._client);

  final drive.DriveApi api;
  final dynamic _client;

  void close() => _client.close();
}
