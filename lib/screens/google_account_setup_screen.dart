import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';

class GoogleAccountSetupScreen extends StatefulWidget {
  final User user;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String suggestedUsername;
  final bool isNewUser;
  final ValueChanged<String>? onCompleted;
  final bool allowCancel;
  final DateTime? initialBirthday;

  const GoogleAccountSetupScreen({
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
  State<GoogleAccountSetupScreen> createState() =>
      _GoogleAccountSetupScreenState();
}

class _GoogleAccountSetupScreenState extends State<GoogleAccountSetupScreen> {
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => widget.allowCancel && !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hesabını tamamla'),
          automaticallyImplyLeading: widget.allowCancel && !_isSaving,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Merhaba! Google ile giriş yaptığın için bilgilerini kaydetmen gerekiyor.\n'
                    'Bu bilgileri doldurup onayladıktan sonra WishLink macerana devam edebilirsin.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _firstNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: _validateFirstName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Soyad'),
                    validator: _validateLastName,
                  ),
                  const SizedBox(height: 16),
                  if (_needsEmailInput) ...[
                    TextFormField(
                      controller: _emailController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _birthdayController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Birth date',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (_) {
                      if (_selectedBirthday == null) {
                        return context.l10n.t(
                          'login.validation.birthDateRequired',
                        );
                      }
                      return null;
                    },
                    onTap: _isSaving ? null : _pickBirthday,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı adı',
                      prefixText: '@',
                    ),
                    validator: _validateUsername,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kaydet ve devam et'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
