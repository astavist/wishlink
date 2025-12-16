// lib/login_screen.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'email_verification_required_screen.dart';
import 'account_setup_screen.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import '../services/google_sign_in_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/wishlink_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignInService.instance;
  final StorageService _storageService = StorageService();
  static const _googleBirthdayScope =
      'https://www.googleapis.com/auth/user.birthday.read';
  static const List<String> _googleScopeHint = <String>[
    'email',
    'profile',
    _googleBirthdayScope,
  ];

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;
  DateTime? _selectedBirthday;

  AppLocalizations get l10n => context.l10n;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _birthdayController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return l10n.t('login.validation.passwordRequired');
    }
    if (value.length < 6) {
      return l10n.t('login.validation.passwordTooShort');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return l10n.t('login.validation.confirmPasswordRequired');
    }
    if (value != _passwordController.text) {
      return l10n.t('login.validation.passwordsMismatch');
    }
    return null;
  }

  String? _validateUsernameFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.t('login.validation.usernameRequired');
    }
    final normalized = value.trim().toLowerCase();
    final regex = RegExp(r'^[a-z0-9._-]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return l10n.t('login.validation.usernameRules');
    }
    return null;
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

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

  Future<bool> _isUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    final normalized = _normalizeUsername(username);
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return true;
    }

    if (excludeUserId != null && query.docs.first.id == excludeUserId) {
      return true;
    }

    return false;
  }

  String _generateUsernameSuggestion({
    String? firstName,
    String? lastName,
    String? email,
  }) {
    final buffer = StringBuffer();
    if (firstName != null && firstName.isNotEmpty) {
      buffer.write(firstName.toLowerCase());
    }
    if (lastName != null && lastName.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('.');
      buffer.write(lastName.toLowerCase());
    }
    if (buffer.isEmpty && email != null && email.isNotEmpty) {
      buffer.write(email.split('@').first.toLowerCase());
    }
    final suggestion = buffer.toString().replaceAll(
      RegExp(r'[^a-z0-9._-]'),
      '',
    );
    if (suggestion.length >= 3) {
      return suggestion;
    }
    return 'wishlover${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  Future<DateTime?> _fetchGoogleBirthday(String? accessToken) async {
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://people.googleapis.com/v1/people/me?personFields=birthdays',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> payload = jsonDecode(response.body);
      final birthdays = payload['birthdays'];
      if (birthdays is! List) {
        return null;
      }

      Map<String, dynamic>? extractEntry(Map<String, dynamic>? entry) {
        final date = entry?['date'];
        if (date is Map<String, dynamic>) {
          final month = date['month'] as int?;
          final day = date['day'] as int?;
          final year = date['year'] as int? ?? 2000;
          if (month != null && day != null) {
            return {'year': year, 'month': month, 'day': day};
          }
        }
        return null;
      }

      Map<String, dynamic>? chosen;
      for (final raw in birthdays) {
        if (raw is Map<String, dynamic>) {
          final metadata = raw['metadata'];
          if (metadata is Map && metadata['primary'] == true) {
            chosen = extractEntry(raw);
            if (chosen != null) {
              break;
            }
          }
        }
      }

      chosen ??= () {
        for (final raw in birthdays) {
          if (raw is Map<String, dynamic>) {
            final extracted = extractEntry(raw);
            if (extracted != null) {
              return extracted;
            }
          }
        }
        return null;
      }();

      if (chosen == null) {
        return null;
      }

      final year = chosen['year'] as int;
      final month = chosen['month'] as int;
      final day = chosen['day'] as int;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncGoogleProfilePhotoIfNeeded({
    required User user,
    required String? providerPhotoUrl,
    required String existingProfilePhotoUrl,
  }) async {
    if (providerPhotoUrl == null ||
        providerPhotoUrl.isEmpty ||
        existingProfilePhotoUrl.isNotEmpty) {
      return;
    }

    try {
      final response = await http.get(Uri.parse(providerPhotoUrl));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return;
      }

      final downloadUrl = await _storageService.uploadProfilePhotoBytes(
        userId: user.uid,
        bytes: response.bodyBytes,
      );

      await _firestore.collection('users').doc(user.uid).set({
        'profilePhotoUrl': downloadUrl,
      }, SetOptions(merge: true));

      try {
        await user.updatePhotoURL(downloadUrl);
      } catch (_) {
        // Ignore failures to populate the auth profile photo.
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to sync Google profile photo: $e');
      debugPrint('$stackTrace');
    }
  }

  Future<String?> _promptForUsername({String? initialValue}) async {
    if (!mounted) return null;

    final controller = TextEditingController(text: initialValue ?? '');
    String? errorText;
    bool isChecking = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final value = controller.text;
              final validationError = _validateUsernameFormat(value);
              if (validationError != null) {
                setState(() {
                  errorText = validationError;
                });
                return;
              }

              setState(() {
                errorText = null;
                isChecking = true;
              });

              final available = await _isUsernameAvailable(value);
              if (!available) {
                setState(() {
                  isChecking = false;
                  errorText = l10n.t('login.validation.usernameTaken');
                });
                return;
              }

              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(_normalizeUsername(value));
              }
            }

            return AlertDialog(
              title: Text(l10n.t('login.chooseUsernameTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('login.chooseUsernameDescription')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      prefixText: '@',
                      errorText: errorText,
                    ),
                  ),
                  if (isChecking)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: Text(l10n.t('common.cancel')),
                ),
                TextButton(
                  onPressed: isChecking ? null : submit,
                  child: Text(l10n.t('common.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _ensureUsernameForUser(
    User user, {
    String? suggestedUsername,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      final currentUsername =
          (snapshot.data()?['username'] as String?)?.trim() ?? '';
      if (currentUsername.isNotEmpty) {
        return true;
      }

      final suggested =
          suggestedUsername ??
          _generateUsernameSuggestion(
            firstName: snapshot.data()?['firstName'] as String?,
            lastName: snapshot.data()?['lastName'] as String?,
            email: user.email,
          );

      final chosenUsername = await _promptForUsername(initialValue: suggested);
      if (chosenUsername == null) {
        await NotificationService.instance.signOutWithCleanup(_auth);
        if (mounted) {
          setState(() {
            _errorMessage = l10n.t('login.usernameRequired');
          });
        }
        return false;
      }

      await docRef.set({'username': chosenUsername}, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.t('login.usernameUpdateFailed');
        });
      }
      return false;
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted && userCredential.user != null) {
        // Check if email is verified
        if (!userCredential.user!.emailVerified) {
          // Send verification email again if needed
          await userCredential.user!.sendEmailVerification();

          // Email verifikasyonu yapılmamış, EmailVerificationRequiredScreen'e yönlendir
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const EmailVerificationRequiredScreen(),
              ),
            );
          }
          return;
        }

        // Update emailVerified status in Firestore
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({'emailVerified': true});

        final ensured = await _ensureUsernameForUser(userCredential.user!);
        if (!ensured) {
          return;
        }

        // User is now signed in, AuthWrapper will automatically navigate to HomeScreen
        // No need to manually navigate as Firebase Auth handles the state
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.t('common.tryAgain');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await GoogleSignInService.ensureInitialized();
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore sign-out errors and continue with sign-in flow.
      }

      final googleUser = await _googleSignIn.authenticate(
        scopeHint: _googleScopeHint,
      );
      final googleAuth = await googleUser.authentication;
      final birthdayToken = await GoogleSignInService.requestAccessToken(
        account: googleUser,
        scopes: const [_googleBirthdayScope],
      );
      final googleBirthday = await _fetchGoogleBirthday(birthdayToken);
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: l10n.t('login.googleNoUser'),
        );
      }

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      final storedProfilePhotoUrl =
          (userDoc.data()?['profilePhotoUrl'] as String?)?.trim() ?? '';

      final displayName = user.displayName?.trim() ?? '';
      final nameParts = displayName.isNotEmpty
          ? displayName.split(RegExp(r'\s+'))
          : <String>[];
      final firstName = nameParts.isNotEmpty
          ? nameParts.first
          : (user.email?.split('@').first ?? googleUser.email);
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      final suggestion = _generateUsernameSuggestion(
        firstName: firstName,
        lastName: lastName,
        email: user.email ?? googleUser.email,
      );

      final currentUsername =
          (userDoc.data()?['username'] as String?)?.trim() ?? '';
      final existingBirthday = userDoc.data()?['birthday'];
      final isNewUser = !userDoc.exists;
      final providerPhotoUrl = googleUser.photoUrl ?? user.photoURL;

      await _syncGoogleProfilePhotoIfNeeded(
        user: user,
        providerPhotoUrl: providerPhotoUrl,
        existingProfilePhotoUrl: storedProfilePhotoUrl,
      );

      if (isNewUser || currentUsername.isEmpty) {
        if (!mounted) {
          return;
        }

        final result = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => AccountSetupScreen(
              user: user,
              firstName: firstName,
              lastName: lastName,
              email: user.email ?? googleUser.email,
              suggestedUsername: suggestion,
              isNewUser: isNewUser,
              initialBirthday: googleBirthday,
            ),
          ),
        );

        if (result == null) {
          await NotificationService.instance.signOutWithCleanup(_auth);
          if (mounted) {
            setState(() {
              _errorMessage = l10n.t('login.googleSetupCancelled');
            });
          }
          return;
        }
      } else {
        if (!(userDoc.data()?['emailVerified'] ?? false)) {
          await userDocRef.update({'emailVerified': true});
        }

        final hasStoredBirthday =
            existingBirthday != null &&
            (existingBirthday is! String || existingBirthday.trim().isNotEmpty);
        if (!hasStoredBirthday && googleBirthday != null) {
          await userDocRef.set({
            'birthday': Timestamp.fromDate(googleBirthday),
          }, SetOptions(merge: true));
        }

        final ensured = await _ensureUsernameForUser(
          user,
          suggestedUsername: suggestion,
        );
        if (!ensured) {
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return;
      }
      setState(() {
        _errorMessage = l10n.t('login.googleFailed');
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.t('login.googleFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      debugPrint(
        'Apple Credential received: userIdentifier=${appleCredential.userIdentifier}',
      );
      debugPrint('Apple identityToken: ${appleCredential.identityToken}');
      debugPrint(
        'Apple authorizationCode: ${appleCredential.authorizationCode}',
      );

      final appleUserId = appleCredential.userIdentifier;
      final identityToken = appleCredential.identityToken;

      if (identityToken == null || identityToken.isEmpty) {
        throw Exception('Apple Sign In failed: identityToken is null or empty');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      debugPrint('Attempting Firebase sign in with Apple credential...');
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      debugPrint(
        'Firebase sign in successful: uid=${userCredential.user?.uid}',
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: l10n.t('login.appleNoUser'),
        );
      }

      debugPrint('Checking Firestore for user document...');
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      debugPrint('User doc exists: ${userDoc.exists}');

      final firstName = (appleCredential.givenName ?? '').trim();
      final lastName = (appleCredential.familyName ?? '').trim();
      // Prefer the email returned on the very first Apple login, fallback to Firebase user email.
      final email = (appleCredential.email ?? user.email)?.trim();

      final suggestion = _generateUsernameSuggestion(
        firstName: firstName.isNotEmpty ? firstName : null,
        lastName: lastName.isNotEmpty ? lastName : null,
        email: email,
      );

      final currentUsername =
          (userDoc.data()?['username'] as String?)?.trim() ?? '';
      final isNewUser = !userDoc.exists;

      if (isNewUser || currentUsername.isEmpty) {
        // Pre-fill minimal info for new users, then show setup screen
        debugPrint('Creating/updating user document in Firestore...');
        debugPrint(
          'isNewUser: $isNewUser, firstName: $firstName, lastName: $lastName, email: $email',
        );

        try {
          await userDocRef.set({
            if (firstName.isNotEmpty) 'firstName': firstName,
            if (lastName.isNotEmpty) 'lastName': lastName,
            if (email != null && email.isNotEmpty) 'email': email,
            if (appleUserId != null) 'appleIdentifier': appleUserId,
            'emailVerified': true,
            if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('Firestore write successful');
        } catch (firestoreError) {
          debugPrint('Firestore write error: $firestoreError');
          rethrow;
        }

        if (!mounted) return;
        debugPrint('Navigating to AccountSetupScreen...');
        final result = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => AccountSetupScreen(
              user: user,
              firstName: firstName.isNotEmpty ? firstName : null,
              lastName: lastName.isNotEmpty ? lastName : null,
              email: email,
              suggestedUsername: suggestion,
              isNewUser: isNewUser,
              initialBirthday: null,
            ),
          ),
        );

        if (result == null) {
          await NotificationService.instance.signOutWithCleanup(_auth);
          if (mounted) {
            setState(() {
              _errorMessage = l10n.t('login.appleSetupCancelled');
            });
          }
          return;
        }
      } else {
        // Existing user: ensure flags and username
        debugPrint('Existing user found, updating info...');

        if (!(userDoc.data()?['emailVerified'] ?? false)) {
          debugPrint('Updating emailVerified flag...');
          await userDocRef.update({'emailVerified': true});
        }

        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          debugPrint('Updating name and Apple identifier...');
          await userDocRef.set({
            if (firstName.isNotEmpty) 'firstName': firstName,
            if (lastName.isNotEmpty) 'lastName': lastName,
            if (appleUserId != null &&
                ((userDoc.data()?['appleIdentifier'] as String?) ?? '').isEmpty)
              'appleIdentifier': appleUserId,
          }, SetOptions(merge: true));
        }

        debugPrint('Ensuring username for existing user...');
        final ensured = await _ensureUsernameForUser(
          user,
          suggestedUsername: suggestion,
        );
        if (!ensured) {
          debugPrint('Username prompt was cancelled');
          return;
        }
        debugPrint('Apple Sign In completed successfully for existing user');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled; just stop loading without error message.
      } else {
        debugPrint(
          'Apple Sign In Authorization Error: ${e.code} - ${e.message}',
        );
        setState(() {
          _errorMessage = kDebugMode
              ? 'Apple Auth Error: ${e.code} - ${e.message}'
              : l10n.t('login.appleFailed');
        });
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'credential-already-in-use') {
        setState(() {
          _errorMessage = l10n.t('login.appleAccountExists');
        });
      } else if (e.code == 'invalid-credential') {
        setState(() {
          _errorMessage = kDebugMode
              ? 'Invalid Credential: ${e.message}'
              : l10n.t('login.appleFailed');
        });
      } else {
        setState(() {
          _errorMessage = kDebugMode
              ? 'Firebase Error [${e.code}]: ${e.message}'
              : _getErrorMessage(e.code);
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Apple Sign In General Error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = kDebugMode ? 'Error: $e' : l10n.t('login.appleFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return l10n.t('login.error.invalidEmail');
      case 'user-disabled':
        return l10n.t('login.error.userDisabled');
      case 'user-not-found':
        return l10n.t('login.error.userNotFound');
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
        return l10n.t('login.error.wrongPassword');
      case 'email-already-in-use':
        return l10n.t('login.error.emailInUse');
      case 'weak-password':
        return l10n.t('login.error.weakPassword');
      default:
        return l10n.t('common.tryAgain');
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final usernameValidation = _validateUsernameFormat(
      _usernameController.text.trim(),
    );
    if (usernameValidation != null) {
      setState(() {
        _errorMessage = usernameValidation;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedBirthday == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.t('login.validation.birthDateRequired');
        });
        return;
      }

      final username = _normalizeUsername(_usernameController.text);
      final available = await _isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.t('login.validation.usernameTaken');
        });
        return;
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await userCredential.user!.sendEmailVerification();

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'username': username,
        'birthday': Timestamp.fromDate(_selectedBirthday!),
        'birthdayDisplay': 'dayMonthYear',
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('login.signupVerificationSent')),
            duration: const Duration(seconds: 5),
          ),
        );

        setState(() {
          _isSignUp = false;
          _firstNameController.clear();
          _lastNameController.clear();
          _usernameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _birthdayController.clear();
          _selectedBirthday = null;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.t('common.tryAgain');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _emailController.clear();
      _passwordController.clear();
      if (_isSignUp) {
        _firstNameController.clear();
        _lastNameController.clear();
        _usernameController.clear();
        _confirmPasswordController.clear();
        _birthdayController.clear();
        _selectedBirthday = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final showAppleSignIn = !kIsWeb && theme.platform == TargetPlatform.iOS;
    final logoAsset = theme.brightness == Brightness.dark
        ? 'assets/images/LogoBlack.png'
        : 'assets/images/Logo.png';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      mediaQuery.size.height - mediaQuery.padding.vertical - 56,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Image.asset(logoAsset, height: 120),
                        const SizedBox(height: 24),
                        WishLinkCard(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          gradient: theme.brightness == Brightness.dark
                              ? const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [Colors.white, Colors.white],
                                ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _AuthModeButton(
                                          text: l10n.t('login.login'),
                                          isSelected: !_isSignUp,
                                          onTap: _isSignUp && !_isLoading
                                              ? _toggleMode
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _AuthModeButton(
                                          text: l10n.t('login.signUp'),
                                          isSelected: _isSignUp,
                                          onTap: !_isSignUp && !_isLoading
                                              ? _toggleMode
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _errorMessage == null
                                      ? const SizedBox.shrink()
                                      : Container(
                                          key: ValueKey(_errorMessage),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.error
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: theme.colorScheme.error,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                if (_isSignUp) ...[
                                  TextFormField(
                                    controller: _firstNameController,
                                    enabled: !_isLoading,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _inputDecoration(
                                      labelText: l10n.t(
                                        'login.label.firstName',
                                      ),
                                      prefixIcon: Icons.person_outline,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n.t(
                                          'login.validation.firstNameRequired',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _lastNameController,
                                    enabled: !_isLoading,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _inputDecoration(
                                      labelText: l10n.t('login.label.lastName'),
                                      prefixIcon: Icons.person_outline,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n.t(
                                          'login.validation.lastNameRequired',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _birthdayController,
                                    readOnly: true,
                                    enabled: !_isLoading,
                                    decoration: _inputDecoration(
                                      labelText: l10n.t(
                                        'login.label.birthDate',
                                      ),
                                      prefixIcon: Icons.cake_outlined,
                                      suffixIcon: const Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                    ),
                                    validator: (_) {
                                      if (_selectedBirthday == null) {
                                        return l10n.t(
                                          'login.validation.birthDateRequired',
                                        );
                                      }
                                      return null;
                                    },
                                    onTap: _isLoading ? null : _pickBirthday,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _usernameController,
                                    enabled: !_isLoading,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    decoration: _inputDecoration(
                                      labelText: l10n.t('login.label.username'),
                                      prefixIcon: Icons.alternate_email,
                                    ),
                                    validator: _validateUsernameFormat,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  enabled: !_isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration(
                                    labelText: l10n.t('login.label.email'),
                                    hintText: l10n.t('login.hint.email'),
                                    prefixIcon: Icons.email_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return l10n.t(
                                        'login.validation.emailRequired',
                                      );
                                    }
                                    if (!value.contains('@') ||
                                        !value.contains('.')) {
                                      return l10n.t(
                                        'login.validation.emailInvalid',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  enabled: !_isLoading,
                                  obscureText: true,
                                  decoration: _inputDecoration(
                                    labelText: l10n.t('login.label.password'),
                                    hintText: '********',
                                    prefixIcon: Icons.lock_outline,
                                  ),
                                  validator: _validatePassword,
                                ),
                                if (_isSignUp) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    enabled: !_isLoading,
                                    obscureText: true,
                                    decoration: _inputDecoration(
                                      labelText: l10n.t(
                                        'login.label.confirmPassword',
                                      ),
                                      prefixIcon: Icons.lock_outline,
                                    ),
                                    validator: _validateConfirmPassword,
                                  ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : (_isSignUp ? _signUp : _signIn),
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : Icon(
                                            _isSignUp
                                                ? Icons.person_add
                                                : Icons.arrow_forward_ios,
                                            size: 20,
                                          ),
                                    label: Text(
                                      _isLoading
                                          ? (_isSignUp
                                                ? l10n.t(
                                                    'login.creatingAccount',
                                                  )
                                                : l10n.t('login.loggingIn'))
                                          : (_isSignUp
                                                ? l10n.t('login.signUp')
                                                : l10n.t('login.login')),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                if (!_isSignUp) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              if (_emailController.text
                                                  .trim()
                                                  .isEmpty) {
                                                setState(() {
                                                  _errorMessage = l10n.t(
                                                    'login.resetEmailInputRequired',
                                                  );
                                                });
                                                return;
                                              }
                                              try {
                                                await _auth
                                                    .sendPasswordResetEmail(
                                                      email: _emailController
                                                          .text
                                                          .trim(),
                                                    );
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.t(
                                                          'login.resetEmailSent',
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                setState(() {
                                                  _errorMessage = l10n.t(
                                                    'login.resetEmailFailed',
                                                  );
                                                });
                                              }
                                            },
                                      child: Text(
                                        l10n.t('login.forgotPassword'),
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!_isSignUp) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  l10n.t('login.orDivider'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _SocialLoginButton(
                            icon: FontAwesomeIcons.google,
                            text: l10n.t('login.continueWithGoogle'),
                            backgroundColor: Colors.transparent,
                            textColor: theme.colorScheme.onSurface.withValues(
                              alpha: 0.9,
                            ),
                            borderSide: BorderSide(
                              color: theme.dividerColor.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.3
                                    : 0.5,
                              ),
                            ),
                            onPressed: _isLoading ? null : _signInWithGoogle,
                          ),
                          if (showAppleSignIn) ...[
                            const SizedBox(height: 16),
                            _SocialLoginButton(
                              icon: FontAwesomeIcons.apple,
                              text: l10n.t('login.continueWithApple'),
                              backgroundColor: Colors.transparent,
                              textColor: theme.colorScheme.onSurface,
                              borderSide: BorderSide(
                                color: theme.dividerColor.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.3
                                      : 0.5,
                                ),
                              ),
                              onPressed: _isLoading ? null : _signInWithApple,
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
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

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(18);
    final baseBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.35 : 0.25,
        ),
        width: 1,
      ),
    );

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      labelStyle: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      filled: isDark,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const _AuthModeButton({
    required this.text,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(24);
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: child),
    );
  }
}

// Özel sosyal medya butonu widget'ı
class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onPressed;
  final BorderSide? borderSide;

  const _SocialLoginButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.onPressed,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, color: textColor),
        label: Text(text, style: TextStyle(fontSize: 18, color: textColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: borderSide ?? BorderSide.none,
          ),
        ),
      ),
    );
  }
}
