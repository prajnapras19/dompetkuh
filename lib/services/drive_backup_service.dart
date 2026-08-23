import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../db/database.dart';
import 'export_import.dart';

/// Only the non-sensitive appdata scope — lets the app read/write its own
/// hidden folder in the user's Drive without Google's app-verification
/// review, and without exposing anything else in their Drive.
const driveScopes = [drive.DriveApi.driveAppdataScope];

const _backupFilePrefix = 'dompetkuh-backup-';
const _maxBackupsToKeep = 5;

class DriveBackupFile {
  final String id;
  final String name;
  final DateTime? createdTime;

  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdTime,
  });
}

/// Google Drive backup/restore against the appDataFolder. Every method
/// takes the signed-in [GoogleSignInAccount] explicitly rather than holding
/// one internally — the currently-signed-in account is Riverpod state
/// (see providers/backup_providers.dart), not this service's concern.
class DriveBackupService {
  Future<drive.DriveApi> _apiFor(GoogleSignInAccount account) async {
    final authorization =
        await account.authorizationClient.authorizationForScopes(
          driveScopes,
        ) ??
        await account.authorizationClient.authorizeScopes(driveScopes);
    return drive.DriveApi(authorization.authClient(scopes: driveScopes));
  }

  Future<void> backup(GoogleSignInAccount account, AppDatabase db) async {
    final api = await _apiFor(account);
    final json = await ExportImport.exportToJson(db);
    final bytes = utf8.encode(json);

    final file = drive.File()
      ..name = '$_backupFilePrefix${DateTime.now().toUtc().toIso8601String()}.json'
      ..parents = ['appDataFolder'];

    await api.files.create(
      file,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
    await _pruneOldBackups(api);
  }

  Future<List<DriveBackupFile>> listBackups(GoogleSignInAccount account) async {
    final api = await _apiFor(account);
    return _listBackups(api);
  }

  Future<List<DriveBackupFile>> _listBackups(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id, name, createdTime)',
      orderBy: 'createdTime desc',
      pageSize: 50,
    );
    return (result.files ?? [])
        .map(
          (f) => DriveBackupFile(
            id: f.id!,
            name: f.name ?? '',
            createdTime: f.createdTime,
          ),
        )
        .toList();
  }

  Future<void> restore(
    GoogleSignInAccount account,
    AppDatabase db,
    String fileId,
  ) async {
    final api = await _apiFor(account);
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    await ExportImport.importFromJson(db, utf8.decode(bytes));
  }

  /// Keeps only the most recent [_maxBackupsToKeep] backups, so the hidden
  /// appDataFolder doesn't grow unbounded over time.
  Future<void> _pruneOldBackups(drive.DriveApi api) async {
    final files = await _listBackups(api);
    if (files.length <= _maxBackupsToKeep) return;
    for (final file in files.skip(_maxBackupsToKeep)) {
      await api.files.delete(file.id);
    }
  }
}
