import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../providers/backup_providers.dart';
import '../../services/drive_backup_service.dart';
import '../../services/google_config.dart';
import '../../theme/colors.dart';

class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (googleServerClientId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Google Drive')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Google Drive backup isn\'t configured yet.\n\n'
              'This needs a Web OAuth client ID from Google Cloud Console, '
              'passed at build time as GOOGLE_SERVER_CLIENT_ID. See '
              'CLAUDE.md for the full setup steps.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final accountAsync = ref.watch(currentGoogleAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (account) => account == null
            ? _SignedOutView(onSignIn: () => _signIn(context, ref))
            : _SignedInView(account: account),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backupActionsProvider).signIn();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    }
  }
}

class _SignedOutView extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignedOutView({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sign in with Google to back up or restore your data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onSignIn, child: const Text('SIGN IN')),
          ],
        ),
      ),
    );
  }
}

class _SignedInView extends ConsumerStatefulWidget {
  final GoogleSignInAccount account;
  const _SignedInView({required this.account});

  @override
  ConsumerState<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends ConsumerState<_SignedInView> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final lastBackupAsync = ref.watch(lastBackupAtProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle, size: 40),
            title: Text(widget.account.displayName ?? widget.account.email),
            subtitle: Text(widget.account.email),
          ),
          const SizedBox(height: 8),
          lastBackupAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (lastBackup) => Text(
              lastBackup == null
                  ? 'No backup yet.'
                  : 'Last backup: ${DateFormat('EEE, d MMM yyyy HH:mm').format(lastBackup.toLocal())}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _signOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
            ),
            child: const Text('SIGN OUT'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _backupNow,
                  child: const Text('BACK UP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('RESTORE'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await ref.read(backupActionsProvider).signOut();
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      await ref.read(backupActionsProvider).backupNow(widget.account);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backed up to Drive.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    List<DriveBackupFile> backups;
    try {
      backups = await ref.read(backupActionsProvider).listBackups(
        widget.account,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not list backups: $e')));
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (backups.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No backups found.')));
      return;
    }

    final selected = await showModalBottomSheet<DriveBackupFile>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose a backup to restore',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final backup in backups)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  backup.createdTime != null
                      ? DateFormat(
                          'EEE, d MMM yyyy HH:mm',
                        ).format(backup.createdTime!.toLocal())
                      : backup.name,
                ),
                onTap: () => Navigator.of(context).pop(backup),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'This replaces all data currently on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: dompetkuhExpenseRed),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(backupActionsProvider)
          .restore(widget.account, selected.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Restore complete.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
