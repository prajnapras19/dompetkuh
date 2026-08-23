import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/drive_backup_service.dart';
import '../services/google_config.dart';
import 'database_provider.dart';

const _lastBackupAtPrefsKey = 'last_backup_at';

final driveBackupServiceProvider = Provider<DriveBackupService>((ref) {
  return DriveBackupService();
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

/// Initializes the GoogleSignIn singleton exactly once. Everything that
/// touches sign-in should `await ref.watch(googleSignInInitProvider.future)`
/// first (see currentGoogleAccountProvider).
final googleSignInInitProvider = FutureProvider<void>((ref) async {
  if (googleServerClientId.isEmpty) {
    // Not configured yet — see services/google_config.dart. Leave
    // GoogleSignIn uninitialized; the UI checks this case separately
    // rather than attempting a doomed sign-in.
    return;
  }
  final signIn = ref.watch(googleSignInProvider);
  await signIn.initialize(serverClientId: googleServerClientId);
});

/// The currently signed-in Google account, or null. Seeded with a silent
/// restore attempt, then kept live via GoogleSignIn's event stream.
final currentGoogleAccountProvider = StreamProvider<GoogleSignInAccount?>((
  ref,
) async* {
  await ref.watch(googleSignInInitProvider.future);
  if (googleServerClientId.isEmpty) {
    yield null;
    return;
  }
  final signIn = ref.watch(googleSignInProvider);

  // A failed silent-restore attempt (e.g. no cached session, or a config
  // error) just means "not signed in" — it must not blow up this stream,
  // or the screen gets stuck on an error with no way back to the Sign In
  // button.
  try {
    final lightweightFuture = signIn.attemptLightweightAuthentication();
    if (lightweightFuture != null) {
      yield await lightweightFuture;
    }
  } catch (_) {
    yield null;
  }

  // Likewise, a cancelled/failed interactive sign-in surfaces as an error
  // event on this stream (GoogleSignIn's AuthenticationEventException).
  // Swallow it here too — BackupActions.signIn()'s own caller already
  // reports that failure via its try/catch — so the stream stays alive and
  // the UI falls back to "not signed in" instead of a dead-end error state.
  yield* signIn.authenticationEvents
      .handleError((Object _, StackTrace _) {})
      .map(
        (event) => switch (event) {
          GoogleSignInAuthenticationEventSignIn(:final user) => user,
          GoogleSignInAuthenticationEventSignOut() => null,
        },
      );
});

final lastBackupAtProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final iso = prefs.getString(_lastBackupAtPrefsKey);
  return iso == null ? null : DateTime.tryParse(iso);
});

class BackupActions {
  BackupActions(this.ref);
  final Ref ref;

  Future<GoogleSignInAccount> signIn() async {
    await ref.read(googleSignInInitProvider.future);
    final signIn = ref.read(googleSignInProvider);
    return signIn.authenticate();
  }

  Future<void> signOut() async {
    final signIn = ref.read(googleSignInProvider);
    await signIn.signOut();
  }

  Future<void> backupNow(GoogleSignInAccount account) async {
    final service = ref.read(driveBackupServiceProvider);
    final db = ref.read(databaseProvider);
    await service.backup(account, db);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupAtPrefsKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    ref.invalidate(lastBackupAtProvider);
  }

  Future<List<DriveBackupFile>> listBackups(GoogleSignInAccount account) {
    final service = ref.read(driveBackupServiceProvider);
    return service.listBackups(account);
  }

  Future<void> restore(GoogleSignInAccount account, String fileId) async {
    final service = ref.read(driveBackupServiceProvider);
    final db = ref.read(databaseProvider);
    await service.restore(account, db, fileId);
  }
}

final backupActionsProvider = Provider<BackupActions>((ref) {
  return BackupActions(ref);
});
