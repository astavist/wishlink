import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GoogleAccountSetupScreen extends StatefulWidget {
  final User user;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String suggestedUsername;
  final bool isNewUser;
  final ValueChanged<String>? onCompleted;
  final bool allowCancel;

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
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your first name';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your last name';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please choose a username';
    }
    final normalized = _normalizeUsername(value);
    final regex = RegExp(r'^[a-z0-9._-]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return '3-20 characters using letters, numbers, ., _, -';
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

    try {
      final available = await _isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _errorMessage = 'This username is already taken';
          _isSaving = false;
        });
        return;
      }

      final data = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'email': widget.email ?? widget.user.email ?? '',
        'username': username,
        'emailVerified': true,
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
        _errorMessage = 'Could not complete setup. Please try again.';
        _isSaving = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Could not complete setup. Please try again.';
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
