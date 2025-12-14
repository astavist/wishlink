import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/locale/locale_controller.dart';

import '../services/account_deletion_service.dart';
import '../services/google_sign_in_service.dart';
import '../theme/theme_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';

const _lightBackground = Color(0xFFFDF9F4);
const _darkBackground = Color(0xFF0F0F0F);
const _heroGradientLightTop = Color(0xFFFFF0DA);
const _heroGradientLightBottom = Color(0xFFF6A441);
const _heroGradientDarkTop = Color(0xFF2A1908);
const _heroGradientDarkBottom = Color(0xFFF2753A);
const _cardLightColor = Colors.white;
const _cardDarkColor = Color(0xFF161616);
const _cardBorderLight = Color(0xFFFFE1C0);
const _cardBorderDark = Color(0x19FFFFFF);
const _dangerGradientStart = Color(0xFFFF7C7C);
const _dangerGradientEnd = Color(0xFFD81E5B);
const double _appBarToolbarHeight = 72;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _ModalSelectionTile<T> extends StatelessWidget {
  const _ModalSelectionTile({
    required this.value,
    required this.groupValue,
    required this.title,
    this.subtitle,
    required this.onChanged,
  });

  final T value;
  final T groupValue;
  final Widget title;
  final Widget? subtitle;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSelected = value == groupValue;
    final Color iconColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        color: iconColor,
      ),
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(value),
    );
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final Uri _supportPortalUri =
      Uri.parse('https://astavist.github.io/wishlink-app/');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AccountDeletionService _accountDeletionService =
      AccountDeletionService();
  final GoogleSignIn _googleSignIn = GoogleSignInService.instance;
  static const List<String> _googleReauthScopes = <String>['email', 'profile'];
  bool _isDeletingAccount = false;

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

  Future<void> _confirmAccountDeletion() async {
    if (_isDeletingAccount) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
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
                backgroundColor: _dangerGradientEnd,
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

  Future<void> _deleteAccount({bool allowReauthAttempt = true}) async {
    if (_isDeletingAccount) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _isDeletingAccount = true;
    });
    var deletionSucceeded = false;
    try {
      await _accountDeletionService.deleteCurrentUserAccount();
      deletionSucceeded = true;
    } on AccountDeletionException catch (e) {
      if (e.code == 'requires-recent-login' && allowReauthAttempt) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isDeletingAccount = false;
        });
        final reauthenticated = await _handleReauthenticationFlow();
        if (reauthenticated && mounted) {
          await _deleteAccount(allowReauthAttempt: false);
        }
        return;
      }
      if (!mounted) return;
      final message = l10n.t(
        'settings.deleteAccountError',
        params: {'error': e.message ?? e.code},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      final message = l10n.t(
        'settings.deleteAccountError',
        params: {'error': '$e'},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeletingAccount = false;
      });
      if (deletionSucceeded) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }
    }
  }

  Future<bool> _handleReauthenticationFlow() async {
    final user = _auth.currentUser;
    final l10n = context.l10n;
    if (user == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('settings.reauth.genericError'))),
      );
      return false;
    }
    final providerIds = user.providerData.map((p) => p.providerId).toSet();
    if (providerIds.contains('password')) {
      return _reauthenticateWithPassword();
    }
    if (providerIds.contains('google.com')) {
      return _reauthenticateWithGoogle();
    }
    if (providerIds.contains('apple.com')) {
      return _reauthenticateWithApple();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('settings.reauth.unsupportedProvider'))),
      );
    }
    return false;
  }

  Future<bool> _reauthenticateWithPassword() async {
    final l10n = context.l10n;
    final password = await _promptForPassword();
    if (password == null) {
      return false;
    }
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('settings.reauth.genericError'))),
        );
      }
      return false;
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final message = e.code == 'wrong-password'
            ? l10n.t('settings.reauth.invalidPassword')
            : (e.message ?? l10n.t('settings.reauth.genericError'));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }
  }

  Future<bool> _reauthenticateWithGoogle() async {
    final l10n = context.l10n;
    await GoogleSignInService.ensureInitialized();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore sign-out issues.
    }
    try {
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: _googleReauthScopes,
      );
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      await user.reauthenticateWithCredential(credential);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('settings.reauth.genericError'))),
        );
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? l10n.t('settings.reauth.genericError')),
          ),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('settings.reauth.genericError'))),
        );
      }
      return false;
    }
  }

  Future<bool> _reauthenticateWithApple() async {
    final l10n = context.l10n;
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw const FormatException('missing-identity-token');
      }
      final credential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? l10n.t('settings.reauth.genericError')),
          ),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('settings.reauth.genericError'))),
        );
      }
      return false;
    }
  }

  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();
    String? errorText;
    final l10n = context.l10n;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(l10n.t('settings.reauth.passwordTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('settings.reauth.passwordMessage')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.t('settings.reauth.passwordPlaceholder'),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setModalState(() {
                        errorText = l10n.t('settings.reauth.passwordRequired');
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  },
                  child: Text(l10n.t('settings.reauth.passwordConfirm')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

  void _openNotificationSettings() {
    Navigator.of(
      context,
    ).push<void>(_buildSlideRoute<void>(const NotificationSettingsScreen()));
  }

  Future<void> _openSupportPortal() async {
    await _openExternalLink(_supportPortalUri);
  }

  Future<void> _openExternalLink(Uri uri) async {
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('common.couldNotOpenLink'))),
      );
    }
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
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? _darkBackground : _lightBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: _appBarToolbarHeight,
        leadingWidth: 72,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 26),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: SizedBox(
          height: 48,
          child: Image.asset(_resolveAppBarAsset(context), fit: BoxFit.contain),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF131313), Color(0xFF1E1E1E)]
                    : const [Color(0xFFFFF5E8), Color(0xFFF7F4EF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(context, user, l10n),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      context: context,
                      title: l10n.t('settings.section.account'),
                      subtitle: l10n.t('settings.section.accountSubtitle'),
                      children: [
                        _buildSettingTile(
                          context: context,
                          icon: Icons.person_outline_rounded,
                          title: l10n.t('settings.editProfile'),
                          onTap: _navigateToEditProfile,
                        ),
                        _buildSettingTile(
                          context: context,
                          icon: Icons.lock_outline_rounded,
                          title: l10n.t('settings.changePassword'),
                          onTap: _navigateToChangePassword,
                        ),
                      ],
                    ),
                    _buildSectionCard(
                      context: context,
                      title: l10n.t('settings.section.preferences'),
                      subtitle: l10n.t('settings.section.preferencesSubtitle'),
                      children: [
                        AnimatedBuilder(
                          animation: themeController,
                          builder: (context, _) {
                            return _buildSettingTile(
                              context: context,
                              icon: Icons.dark_mode_outlined,
                              title: l10n.t('settings.appearance'),
                              subtitle: l10n.t(
                                'settings.appearance.chooseTheme',
                              ),
                              valueText: _themeModeLabel(
                                themeController.themeMode,
                                l10n,
                              ),
                              onTap: () => _selectTheme(themeController, l10n),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: localeController,
                          builder: (context, _) {
                            return _buildSettingTile(
                              context: context,
                              icon: Icons.language_rounded,
                              title: l10n.t('common.language'),
                              subtitle: l10n.t('common.languagePrompt'),
                              valueText: _languageLabel(
                                localeController.locale,
                                l10n,
                              ),
                              onTap: () =>
                                  _selectLanguage(localeController, l10n),
                            );
                          },
                        ),
                      ],
                    ),
                    _buildSectionCard(
                      context: context,
                      title: l10n.t('settings.section.support'),
                      subtitle: l10n.t('settings.section.supportSubtitle'),
                      children: [
                        _buildSettingTile(
                          context: context,
                          icon: Icons.notifications_none_rounded,
                          title: l10n.t('settings.notifications'),
                          subtitle: l10n.t('settings.notifications.lede'),
                          onTap: _openNotificationSettings,
                        ),
                        _buildSettingTile(
                          context: context,
                          icon: Icons.privacy_tip_outlined,
                          title: l10n.t('settings.privacy'),
                          subtitle: l10n.t('settings.privacyComing'),
                          onTap: _openSupportPortal,
                        ),
                        _buildSettingTile(
                          context: context,
                          icon: Icons.help_outline_rounded,
                          title: l10n.t('settings.help'),
                          subtitle: l10n.t('settings.helpComing'),
                          onTap: _openSupportPortal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSignOutButton(
                      context,
                      l10n,
                      enabled: !_isDeletingAccount,
                    ),
                    const SizedBox(height: 12),
                    _buildDeleteAccountButton(context, l10n),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('settings.deleteAccountSubtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isDeletingAccount) _buildDeletionOverlay(context, l10n),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    User? user,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = user?.displayName?.trim();
    final fallbackName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (user?.email?.split('@').first ?? l10n.t('settings.title'));
    final email = user?.email ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [_heroGradientDarkTop, _heroGradientDarkBottom]
              : const [_heroGradientLightTop, _heroGradientLightBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0x66F6A441),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildHeroAvatar(context, user),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fallbackName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('settings.signedInAs', params: {'email': email}),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAvatar(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final photoUrl = user?.photoURL;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(radius: 32, backgroundImage: NetworkImage(photoUrl));
    }

    final initial = _userInitial(user);
    return CircleAvatar(
      radius: 32,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: theme.textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _userInitial(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFFFE9D3);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: isDark ? _cardDarkColor : _cardLightColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? _cardBorderDark : _cardBorderLight),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0x1AF6A441),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ..._buildSectionChildren(children, dividerColor),
        ],
      ),
    );
  }

  List<Widget> _buildSectionChildren(
    List<Widget> children,
    Color dividerColor,
  ) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Divider(height: 1, thickness: 1, color: dividerColor));
      }
    }
    return items;
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    String? valueText,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBackground = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.15 : 0.08,
    );
    final iconColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (valueText != null) ...[
                Text(
                  valueText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: theme.iconTheme.color?.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(
    BuildContext context,
    AppLocalizations l10n, {
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: enabled ? _signOut : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_dangerGradientStart, _dangerGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _dangerGradientEnd.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Text(
            l10n.t('common.signOut'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final accent = _dangerGradientEnd;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isDeletingAccount ? null : _confirmAccountDeletion,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          side: BorderSide(color: accent.withValues(alpha: 0.75)),
          foregroundColor: accent,
          textStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.delete_forever_rounded),
        label: Text(l10n.t('settings.deleteAccount')),
      ),
    );
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }

  Future<void> _selectLanguage(
    LocaleController controller,
    AppLocalizations l10n,
  ) async {
    final selectedLocale = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? _cardDarkColor
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
                    (locale) => _ModalSelectionTile<Locale>(
                      value: locale,
                      groupValue: pendingSelection,
                      title: Text(_languageLabel(locale, l10n)),
                      onChanged: (value) {
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? _cardDarkColor
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
                  _ModalSelectionTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: pendingSelection,
                    title: Text(l10n.t('settings.appearance.matchSystem')),
                    subtitle: Text(
                      l10n.t('settings.appearance.matchSystemDesc'),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        pendingSelection = value;
                      });
                    },
                  ),
                  _ModalSelectionTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: pendingSelection,
                    title: Text(l10n.t('settings.appearance.light')),
                    subtitle: Text(l10n.t('settings.appearance.lightDesc')),
                    onChanged: (value) {
                      setModalState(() {
                        pendingSelection = value;
                      });
                    },
                  ),
                  _ModalSelectionTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: pendingSelection,
                    title: Text(l10n.t('settings.appearance.dark')),
                    subtitle: Text(l10n.t('settings.appearance.darkDesc')),
                    onChanged: (value) {
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
        return l10n.t('settings.appearance.matchSystem');
    }
  }

  String _languageLabel(Locale locale, AppLocalizations l10n) {
    switch (locale.languageCode.toLowerCase()) {
      case 'tr':
        return l10n.t('common.turkish');
      case 'en':
        return l10n.t('common.english');
    }
    return l10n.t('common.english');
  }

  Widget _buildDeletionOverlay(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 42,
                  width: 42,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t('settings.deleteAccountInProgress'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
