import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../db/database.dart';
import 'export_import.dart';

/// The non-sensitive drive.file scope — lets the app see and manage only
/// the files/folders it creates itself, so backups land in a normal,
/// visible "Dompetkuh Backups" folder in the user's own Drive (like the
/// reference app does) rather than the hidden appDataFolder, while still
/// not exposing the rest of their Drive and still not needing Google's
/// app-verification review.
const driveScopes = [drive.DriveApi.driveFileScope];

const _backupFolderName = 'Dompetkuh Backups';
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

/// Google Drive backup/restore against a visible "Dompetkuh Backups" folder
/// in the user's My Drive. Every method takes the signed-in
/// [GoogleSignInAccount] explicitly rather than holding one internally —
/// the currently-signed-in account is Riverpod state (see
/// providers/backup_providers.dart), not this service's concern.
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
    final folderId = await _folderId(api);
    final json = await ExportImport.exportToJson(db);
    final bytes = utf8.encode(json);

    final file = drive.File()
      ..name = '$_backupFilePrefix${DateTime.now().toUtc().toIso8601String()}.json'
      ..parents = [folderId];

    await api.files.create(
      file,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
    await _pruneOldBackups(api, folderId);
  }

  Future<List<DriveBackupFile>> listBackups(GoogleSignInAccount account) async {
    final api = await _apiFor(account);
    final folderId = await _folderId(api);
    return _listBackups(api, folderId);
  }

  /// Finds the visible "Dompetkuh Backups" folder in the user's My Drive,
  /// creating it on first use. drive.file scope only grants access to
  /// files/folders the app itself creates, so this must always be found
  /// (or (re)created) rather than assumed to exist — e.g. if the user
  /// deleted it since the last backup.
  Future<String> _folderId(drive.DriveApi api) async {
    final result = await api.files.list(
      q:
          "name = '$_backupFolderName' and "
          "mimeType = 'application/vnd.google-apps.folder' and "
          "trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
      pageSize: 1,
    );
    final existing = result.files;
    if (existing != null && existing.isNotEmpty) {
      return existing.first.id!;
    }

    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<List<DriveBackupFile>> _listBackups(
    drive.DriveApi api,
    String folderId,
  ) async {
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      spaces: 'drive',
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

  /// Keeps only the most recent [_maxBackupsToKeep] backups, so the Drive
  /// folder doesn't grow unbounded over time.
  Future<void> _pruneOldBackups(drive.DriveApi api, String folderId) async {
    final files = await _listBackups(api, folderId);
    if (files.length <= _maxBackupsToKeep) return;
    for (final file in files.skip(_maxBackupsToKeep)) {
      await api.files.delete(file.id);
    }
  }
}
