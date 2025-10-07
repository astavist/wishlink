import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme_controller.dart';
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
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error signing out')));
    }
  }

  Future<void> _navigateToEditProfile() async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(_buildSlideRoute<bool>(const EditProfileScreen()));
    if (!mounted) return;
    if (updated == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToEditProfile,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToChangePassword,
          ),
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              return ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Appearance'),
                subtitle: Text(_themeModeLabel(themeController.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTheme(themeController),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Notifications - Coming Soon'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Privacy Settings - Coming Soon'),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Help & Support - Coming Soon'),
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
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTheme(ThemeController controller) async {
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
                  const Text(
                    'Choose theme',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: pendingSelection,
                    title: const Text('Match system'),
                    subtitle: const Text('Automatically follows your device'),
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
                    title: const Text('Light'),
                    subtitle: const Text('Always use the light theme'),
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
                    title: const Text('Dark'),
                    subtitle: const Text('Always use the dark theme'),
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
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(pendingSelection),
                        child: const Text('Apply'),
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

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
      default:
        return 'Match system';
    }
  }
}
