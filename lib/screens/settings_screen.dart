import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme_controller.dart';
import 'package:wishlink/locale/locale_controller.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('settings.errorSigningOut'))),
      );
    }
  }

  Future<void> _navigateToEditProfile() async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(_buildSlideRoute<bool>(const EditProfileScreen()));
    if (!mounted) return;
    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('settings.profileUpdated'))),
      );
    }
  }

  void _navigateToChangePassword() {
    Navigator.of(
      context,
    ).push<void>(_buildSlideRoute<void>(const ChangePasswordScreen()));
  }

  Route<T> _buildSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      // ignore: unnecessary_underscores
      pageBuilder: (_, __, ___) => page,
      // ignore: unnecessary_underscores
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerProvider.of(context);
    final localeController = LocaleControllerProvider.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings.title')),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(l10n.t('settings.editProfile')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToEditProfile,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(l10n.t('settings.changePassword')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToChangePassword,
          ),
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              return ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(l10n.t('settings.appearance')),
                subtitle: Text(
                  _themeModeLabel(themeController.themeMode, l10n),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTheme(themeController, l10n),
              );
            },
          ),
          AnimatedBuilder(
            animation: localeController,
            builder: (context, _) {
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.t('common.language')),
                subtitle: Text(_languageLabel(localeController.locale, l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectLanguage(localeController, l10n),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(l10n.t('settings.notifications')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showComingSoon(l10n.t('settings.notificationsComing')),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(l10n.t('settings.privacy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(l10n.t('settings.privacyComing')),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: Text(l10n.t('settings.help')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(l10n.t('settings.helpComing')),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _signOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.t('common.signOut')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLanguage(
    LocaleController controller,
    AppLocalizations l10n,
  ) async {
    final selectedLocale = await showModalBottomSheet<Locale>(
      context: context,
      builder: (context) {
        var pendingSelection = controller.locale;
        final locales = LocaleController.supportedLocales;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.t('common.languagePrompt'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...locales.map(
                    (locale) => RadioListTile<Locale>(
                      value: locale,
                      groupValue: pendingSelection,
                      title: Text(_languageLabel(locale, l10n)),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          pendingSelection = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.t('common.cancel')),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(pendingSelection),
                        child: Text(l10n.t('common.apply')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedLocale == null) {
      return;
    }

    await controller.updateLocale(selectedLocale);
  }

  Future<void> _selectTheme(
    ThemeController controller,
    AppLocalizations l10n,
  ) async {
    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        var pendingSelection = controller.themeMode;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.t('settings.appearance.chooseTheme'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: pendingSelection,
                    title: Text(l10n.t('settings.appearance.matchSystem')),
                    subtitle: Text(
                      l10n.t('settings.appearance.matchSystemDesc'),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pendingSelection = value;
                      });
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: pendingSelection,
                    title: Text(l10n.t('settings.appearance.light')),
                    subtitle: Text(l10n.t('settings.appearance.lightDesc')),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pendingSelection = value;
                      });
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: pendingSelection,
                    title: Text(l10n.t('settings.appearance.dark')),
                    subtitle: Text(l10n.t('settings.appearance.darkDesc')),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pendingSelection = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.t('common.cancel')),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(pendingSelection),
                        child: Text(l10n.t('common.apply')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedMode == null) {
      return;
    }

    await controller.updateThemeMode(selectedMode);
  }

  String _themeModeLabel(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.t('settings.appearance.light');
      case ThemeMode.dark:
        return l10n.t('settings.appearance.dark');
      case ThemeMode.system:
      default:
        return l10n.t('settings.appearance.matchSystem');
    }
  }

  String _languageLabel(Locale locale, AppLocalizations l10n) {
    switch (locale.languageCode.toLowerCase()) {
      case 'tr':
        return l10n.t('common.turkish');
      case 'en':
      default:
        return l10n.t('common.english');
    }
  }
}
