import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/services/account_deletion_service.dart';
import 'package:wishlink/services/notification_service.dart';

class BannedUserScreen extends StatefulWidget {
  const BannedUserScreen({super.key});

  @override
  State<BannedUserScreen> createState() => _BannedUserScreenState();
}

class _BannedUserScreenState extends State<BannedUserScreen> {
  static final Uri _supportUri = Uri.parse(
    'https://astavist.github.io/wishlink-app/',
  );
  final AccountDeletionService _accountDeletionService =
      AccountDeletionService();
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;

  Future<void> _signOut() async {
    if (_isSigningOut || _isDeletingAccount) {
      return;
    }
    setState(() {
      _isSigningOut = true;
    });
    final l10n = context.l10n;
    try {
      await NotificationService.instance
          .signOutWithCleanup(FirebaseAuth.instance);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('settings.errorSigningOut'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _openSupport() async {
    final l10n = context.l10n;
    try {
      final launched = await launchUrl(
        _supportUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('banned.supportError'))),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('banned.supportError'))),
      );
    }
  }

  Future<void> _confirmAccountDeletion() async {
    if (_isDeletingAccount) {
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('settings.deleteAccountConfirmTitle')),
          content: Text(l10n.t('settings.deleteAccountConfirmMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('settings.deleteAccountConfirmAction')),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) {
      return;
    }
    setState(() {
      _isDeletingAccount = true;
    });
    final l10n = context.l10n;
    try {
      await _accountDeletionService.deleteCurrentUserAccount();
    } on AccountDeletionException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.code == 'requires-recent-login'
          ? l10n.t('banned.deleteReauthRequired')
          : l10n.t(
              'settings.deleteAccountError',
              params: {'error': error.message ?? error.code},
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(
              'settings.deleteAccountError',
              params: {'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.t('banned.modalTitle'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.t('banned.modalDescription'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: _isSigningOut || _isDeletingAccount
                              ? null
                              : _signOut,
                          icon: _isSigningOut
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.logout_rounded),
                          label: Text(l10n.t('banned.signOut')),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isDeletingAccount ? null : _openSupport,
                          icon: const Icon(Icons.support_agent_rounded),
                          label: Text(l10n.t('banned.support')),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed:
                              _isDeletingAccount ? null : _confirmAccountDeletion,
                          icon: _isDeletingAccount
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.error,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.delete_forever_rounded,
                                  color: theme.colorScheme.error,
                                ),
                          label: Text(
                            l10n.t('banned.deleteAccount'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
