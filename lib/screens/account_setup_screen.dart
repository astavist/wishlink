import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/screens/login_screen.dart';
import 'package:wishlink/services/notification_service.dart';

class AccountSetupScreen extends StatefulWidget {
  final User user;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String suggestedUsername;
  final bool isNewUser;
  final ValueChanged<String>? onCompleted;
  final bool allowCancel;
  final DateTime? initialBirthday;

  const AccountSetupScreen({
    super.key,
    required this.user,
    this.firstName,
    this.lastName,
    this.email,
    required this.suggestedUsername,
    this.isNewUser = false,
    this.onCompleted,
    this.allowCancel = true,
    this.initialBirthday,
  });

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  static const LinearGradient _brandGradient = LinearGradient(
    colors: [Color(0xFFFDD27B), Color(0xFFF6A441)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _emailController;
  DateTime? _selectedBirthday;
  late final bool _needsEmailInput;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final displayName = widget.user.displayName?.trim() ?? '';
    final nameParts = displayName.isNotEmpty
        ? displayName.split(RegExp(r'\s+'))
        : <String>[];

    final providedFirstName = widget.firstName?.trim() ?? '';
    final providedLastName = widget.lastName?.trim() ?? '';
    final providedEmail = widget.email?.trim() ?? '';

    final initialFirstName = providedFirstName.isNotEmpty
        ? providedFirstName
        : (nameParts.isNotEmpty ? nameParts.first : '');
    final initialLastName = providedLastName.isNotEmpty
        ? providedLastName
        : (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    _firstNameController = TextEditingController(text: initialFirstName);
    _lastNameController = TextEditingController(text: initialLastName);
    _usernameController = TextEditingController(
      text: widget.suggestedUsername.toLowerCase(),
    );
    _needsEmailInput = providedEmail.isEmpty;
    _emailController = TextEditingController(text: providedEmail);
    _selectedBirthday = widget.initialBirthday;
    _birthdayController = TextEditingController(
      text: _selectedBirthday != null ? _formatDate(_selectedBirthday!) : '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final minSelectable = DateTime(now.year - 120, now.month, now.day);
    final fallbackInitial = DateTime(now.year - 18, now.month, now.day);
    final initial = _selectedBirthday ?? fallbackInitial;

    final chosenDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(minSelectable) ? minSelectable : initial,
      firstDate: minSelectable,
      lastDate: now,
    );

    if (chosenDate != null) {
      final normalized = DateTime(
        chosenDate.year,
        chosenDate.month,
        chosenDate.day,
      );
      setState(() {
        _selectedBirthday = normalized;
        _birthdayController.text = _formatDate(normalized);
      });
    }
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.t('login.validation.firstNameRequired');
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.t('login.validation.lastNameRequired');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.t('login.validation.emailRequired');
    }
    final normalized = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(normalized)) {
      return context.l10n.t('login.validation.emailInvalid');
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.t('login.validation.usernameRequired');
    }
    final normalized = _normalizeUsername(value);
    final regex = RegExp(r'^[a-z0-9._-]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return context.l10n.t('login.validation.usernameRules');
    }
    return null;
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final normalized = _normalizeUsername(username);
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return true;
    }

    return snapshot.docs.first.id == widget.user.uid;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _normalizeUsername(_usernameController.text);
    final email = _needsEmailInput
        ? _emailController.text.trim()
        : (widget.email?.trim() ?? widget.user.email ?? '');
    final l10n = context.l10n;

    try {
      if (_selectedBirthday == null) {
        setState(() {
          _errorMessage = l10n.t('login.validation.birthDateRequired');
          _isSaving = false;
        });
        return;
      }

      if (_needsEmailInput) {
        final emailValidation = _validateEmail(email);
        if (emailValidation != null) {
          setState(() {
            _errorMessage = emailValidation;
            _isSaving = false;
          });
          return;
        }
      }

      final available = await _isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _errorMessage = l10n.t('login.validation.usernameTaken');
          _isSaving = false;
        });
        return;
      }

      final data = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'username': username,
        'emailVerified': true,
        'birthday': Timestamp.fromDate(_selectedBirthday!),
        'birthdayDisplay': 'dayMonthYear',
      };
      if (widget.isNewUser) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set(data, SetOptions(merge: true));

      final displayName = [
        firstName,
        lastName,
      ].where((value) => value.isNotEmpty).join(' ');
      if (displayName.isNotEmpty) {
        await widget.user.updateDisplayName(displayName);
      }

      if (!mounted) {
        return;
      }

      final onCompleted = widget.onCompleted;
      if (onCompleted != null) {
        onCompleted(username);
      } else {
        Navigator.of(context).pop(username);
      }
    } on FirebaseAuthException catch (_) {
      setState(() {
        _errorMessage = l10n.t('accountSetup.saveFailed');
        _isSaving = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = l10n.t('accountSetup.saveFailed');
        _isSaving = false;
      });
    }
  }

  Future<void> _cancelSetup() async {
    if (!widget.allowCancel || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? widget.user;
    final userId = user.uid;

    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      try {
        final snapshot = await userDoc.get();
        if (snapshot.exists) {
          await userDoc.delete();
        }
      } catch (_) {
        // Ignore document cleanup failures.
      }

      try {
        await user.delete();
      } on FirebaseAuthException catch (_) {
        // Ignore deletion errors; we'll still sign out below.
      }
      } finally {
        await NotificationService.instance.signOutWithCleanup(auth);
      }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0F0F0F), const Color(0xFF191919)]
          : [const Color(0xFFFFF5E3), Colors.white],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (!widget.allowCancel || _isSaving) {
          return;
        }
        await _cancelSetup();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leadingWidth: 0,
          leading: const SizedBox.shrink(),
          title: Image.asset(
            _resolveAppBarAsset(context),
            height: 60,
            fit: BoxFit.contain,
          ),
        ),
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSection(context),
                      const SizedBox(height: 24),
                      Form(key: _formKey, child: _buildFormCard(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: _brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF6A441).withValues(alpha: 0.35),
            offset: const Offset(0, 24),
            blurRadius: 48,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.celebration_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l10n.t('accountSetup.title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('accountSetup.intro'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.dark
        ? const Color(0xFF1B1B1B)
        : Colors.white;

    InputDecoration decoration({
      required String label,
      IconData? icon,
      String? prefixText,
      bool readOnly = false,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        prefixText: prefixText,
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? const Color(0xFF242424)
            : const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        suffixIcon: readOnly
            ? const Icon(Icons.keyboard_arrow_down_rounded)
            : null,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.4 : 0.08,
            ),
            offset: const Offset(0, 25),
            blurRadius: 60,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            decoration: decoration(
              label: l10n.t('login.label.firstName'),
              icon: Icons.person_outline,
            ),
            validator: _validateFirstName,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            decoration: decoration(
              label: l10n.t('login.label.lastName'),
              icon: Icons.person_outline_rounded,
            ),
            validator: _validateLastName,
          ),
          const SizedBox(height: 16),
          if (_needsEmailInput) ...[
            TextFormField(
              controller: _emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: decoration(
                label: l10n.t('login.label.email'),
                icon: Icons.email_outlined,
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _birthdayController,
            readOnly: true,
            decoration: decoration(
              label: l10n.t('login.label.birthDate'),
              icon: Icons.cake_outlined,
              readOnly: true,
            ),
            validator: (_) {
              if (_selectedBirthday == null) {
                return context.l10n.t('login.validation.birthDateRequired');
              }
              return null;
            },
            onTap: _isSaving ? null : _pickBirthday,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.done,
            decoration: decoration(
              label: l10n.t('login.label.username'),
              icon: Icons.alternate_email,
              prefixText: '@',
            ),
            validator: _validateUsername,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.redAccent,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: _brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.t('accountSetup.saveButton'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (widget.allowCancel) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _cancelSetup,
              icon: const Icon(Icons.logout),
              label: Text(l10n.t('accountSetup.cancelAndReturn')),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }
}
