import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';

import '../models/notification_preferences.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  NotificationPreferences _preferences =
      const NotificationPreferences.defaults();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _statusMessage;
  Timer? _statusTimer;
  bool _hasRequestedLoad = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasRequestedLoad) {
      return;
    }
    _hasRequestedLoad = true;
    _loadPreferences();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final l10n = context.l10n;
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.t('notifications.userNotAuthenticated');
      });
      return;
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final prefData =
          data['notificationPreferences'] as Map<String, dynamic>?;
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = NotificationPreferences.fromMap(prefData);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            l10n.t('settings.notifications.loadError', params: {'error': '$e'});
      });
    }
  }

  Future<void> _persistPreferences(NotificationPreferences prefs) async {
    final l10n = context.l10n;
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('users').doc(user.uid).set(
            {
              'notificationPreferences': prefs.toMap(),
              'notificationsEnabled': prefs.pushEnabled,
            },
            SetOptions(merge: true),
          );
      _showTemporaryStatus(l10n.t('settings.notifications.saved'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('settings.notifications.saveError', params: {'error': '$e'}),
          ),
        ),
      );
      setState(() {
        _preferences = prefs;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _togglePush(bool value) async {
    final previous = _preferences;
    final l10n = context.l10n;

    setState(() {
      _preferences = _preferences.copyWith(pushEnabled: value);
    });

    final service = NotificationService.instance;
    final success = await service.updateUserPreference(value);
    if (!success) {
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('settings.notifications.permissionDenied')),
        ),
      );
      return;
    }

    await _persistPreferences(_preferences);
  }

  Future<void> _updatePreference(NotificationPreferences prefs) async {
    setState(() {
      _preferences = prefs;
    });
    await _persistPreferences(prefs);
  }

  void _showTemporaryStatus(String message) {
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message;
    });
    _statusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDF9F4);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(l10n.t('settings.notifications')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _buildBody(theme, l10n),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadPreferences,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('settings.notifications.lede'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        _PreferenceCard(
          child: Column(
            children: [
              _SettingsSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: l10n.t('settings.notifications.pushTitle'),
                subtitle: l10n.t('settings.notifications.pushSubtitle'),
                value: _preferences.pushEnabled,
                onChanged: _togglePush,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  _preferences.pushEnabled
                      ? l10n.t('settings.notifications.statusEnabled')
                      : l10n.t('settings.notifications.statusDisabled'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PreferenceCard(
          child: Column(
            children: [
              _SettingsSwitchTile(
                enabled: _preferences.pushEnabled,
                icon: Icons.group_add_outlined,
                title: l10n.t('settings.notifications.friendRequests'),
                subtitle: l10n.t('settings.notifications.friendRequestsSubtitle'),
                value: _preferences.friendRequestAlerts,
                onChanged: (value) {
                  _updatePreference(
                    _preferences.copyWith(friendRequestAlerts: value),
                  );
                },
              ),
              const Divider(height: 1),
              _SettingsSwitchTile(
                enabled: _preferences.pushEnabled,
                icon: Icons.card_giftcard_outlined,
                title: l10n.t('settings.notifications.friendActivity'),
                subtitle: l10n.t('settings.notifications.friendActivitySubtitle'),
                value: _preferences.friendActivityAlerts,
                onChanged: (value) {
                  _updatePreference(
                    _preferences.copyWith(friendActivityAlerts: value),
                  );
                },
              ),
              const Divider(height: 1),
              _SettingsSwitchTile(
                enabled: _preferences.pushEnabled,
                icon: Icons.auto_awesome_outlined,
                title: l10n.t('settings.notifications.tips'),
                subtitle: l10n.t('settings.notifications.tipsSubtitle'),
                value: _preferences.inspirationTips,
                onChanged: (value) {
                  _updatePreference(
                    _preferences.copyWith(inspirationTips: value),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isSaving)
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.t('settings.notifications.saving'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          )
        else if (_statusMessage != null)
          Text(
            _statusMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDark ? Colors.white.withAlpha(28) : const Color(0xFFFFE1C0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 24,
                  offset: const Offset(0, 18),
                )
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(
                theme.brightness == Brightness.dark ? 0.15 : 0.08,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(context.l10n.t('notifications.retry')),
          ),
        ],
      ),
    );
  }
}
