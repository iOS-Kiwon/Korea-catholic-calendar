import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class PersonalCloudBackupStore {
  const PersonalCloudBackupStore({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.sidore.catholiccalendar/personal_backup');

  final MethodChannel _channel;
  static const _driveScopes = [drive.DriveApi.driveAppdataScope];
  static const _driveFileName = 'personalDataSnapshotV1.json';
  static Future<void>? _googleSignInInitialization;

  Future<String?> loadSnapshotJson() async {
    if (_usesGoogleDriveBackup) {
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

  Future<bool> saveSnapshotJson(String snapshotJson) async {
    if (_usesGoogleDriveBackup) {
      return _saveGoogleDriveSnapshotJson(snapshotJson);
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
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
  }

  Future<_GoogleDriveSession?> _driveSession({
    required bool promptIfNeeded,
  }) async {
    try {
      await _ensureGoogleSignInInitialized();

      final googleSignIn = GoogleSignIn.instance;
      GoogleSignInAccount? account;
      final lightweight = googleSignIn.attemptLightweightAuthentication();
      if (lightweight != null) {
        account = await lightweight;
      }

      if (account == null &&
          promptIfNeeded &&
          googleSignIn.supportsAuthenticate()) {
        account = await googleSignIn.authenticate(scopeHint: _driveScopes);
      }

      if (account == null) return null;

      final authorization =
          await account.authorizationClient.authorizationForScopes(
            _driveScopes,
          ) ??
          (promptIfNeeded
              ? await account.authorizationClient.authorizeScopes(_driveScopes)
              : null);
      if (authorization == null) return null;

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

  Future<bool> _saveGoogleDriveSnapshotJson(String snapshotJson) async {
    final session = await _driveSession(promptIfNeeded: true);
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
