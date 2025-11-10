import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';

const _lightBackground = Color(0xFFFDF9F4);
const _darkBackground = Color(0xFF0F0F0F);
const _cardLightColor = Colors.white;
const _cardDarkColor = Color(0xFF161616);
const _cardBorderLight = Color(0xFFFFE1C0);
const _cardBorderDark = Color(0x19FFFFFF);
const _heroGradientLightTop = Color(0xFFFFF0DA);
const _heroGradientLightBottom = Color(0xFFF6A441);
const _heroGradientDarkTop = Color(0xFF2A1908);
const _heroGradientDarkBottom = Color(0xFFF2753A);
const _primaryButtonColor = Color(0xFFF2753A);
const _primaryButtonDark = Color(0xFFF6A441);

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final l10n = context.l10n;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Unable to find authenticated user.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('changePassword.updateSuccess'))),
      );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? l10n.t('changePassword.updateFailed')),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('common.tryAgain'))));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? _darkBackground : _lightBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Image.asset(_resolveAppBarAsset(context), height: 42),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(context, l10n),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      context: context,
                      title: l10n.t('changePassword.title'),
                      subtitle: l10n.t('changePassword.subtitle'),
                      children: [
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('changePassword.currentLabel'),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.t('changePassword.currentRequired');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('changePassword.newLabel'),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.t('changePassword.newRequired');
                            }
                            if (value.length < 6) {
                              return l10n.t('changePassword.newTooShort');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('changePassword.confirmLabel'),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.t('changePassword.confirmRequired');
                            }
                            if (value != _newPasswordController.text) {
                              return l10n.t('changePassword.mismatch');
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    _buildPrimaryButton(context, l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('changePassword.heroTitle'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t('changePassword.heroSubtitle'),
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

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
          ...children,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: color, width: 1),
      );
    }

    final Color baseColor = isDark ? _cardBorderDark : _cardBorderLight;

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: border(baseColor),
      enabledBorder: border(baseColor),
      focusedBorder: border(isDark ? _primaryButtonDark : _primaryButtonColor),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? _primaryButtonDark
              : _primaryButtonColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(l10n.t('changePassword.saveButton')),
      ),
    );
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }
}
