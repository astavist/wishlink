// lib/login_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'email_verification_required_screen.dart';
import 'google_account_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateUsernameFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please choose a username';
    }
    final normalized = value.trim().toLowerCase();
    final regex = RegExp(r'^[a-z0-9._-]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return 'Username must be 3-20 characters and can include letters, numbers, ., _, -';
    }
    return null;
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

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
                  errorText = 'This username is already taken';
                });
                return;
              }

              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(_normalizeUsername(value));
              }
            }

            return AlertDialog(
              title: const Text('Choose a username'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pick a unique username so your friends can find you easily.',
                  ),
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
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isChecking ? null : submit,
                  child: const Text('Save'),
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
        await _auth.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = 'A username is required to continue.';
          });
        }
        return false;
      }

      await docRef.set({'username': chosenUsername}, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'We could not update your username. Please try again.';
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
        _errorMessage = 'An error occurred. Please try again.';
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
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore sign-out errors and continue with sign-in flow.
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user returned from Google sign-in.',
        );
      }

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

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
      final isNewUser = !userDoc.exists;

      if (isNewUser || currentUsername.isEmpty) {
        if (!mounted) {
          return;
        }

        final result = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => GoogleAccountSetupScreen(
              user: user,
              firstName: firstName,
              lastName: lastName,
              email: user.email ?? googleUser.email,
              suggestedUsername: suggestion,
              isNewUser: isNewUser,
            ),
          ),
        );

        if (result == null) {
          await _auth.signOut();
          if (mounted) {
            setState(() {
              _errorMessage = 'Google account setup was cancelled.';
            });
          }
          return;
        }
      } else {
        if (!(userDoc.data()?['emailVerified'] ?? false)) {
          await userDocRef.update({'emailVerified': true});
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
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-in failed. Please try again.';
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
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found with these credentials.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Your password must be at least 6 characters.';
      default:
        return 'An error occurred. Please try again.';
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
      final username = _normalizeUsername(_usernameController.text);
      final available = await _isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This username is already taken';
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
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent. Please check your inbox and verify your email before logging in.',
            ),
            duration: Duration(seconds: 5),
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
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAppleSignIn =
        !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        color: Colors.white,
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    // Logo ve Başlık
                    SizedBox(
                      height: 150,
                      child: Image.asset('assets/images/LogoPNG.png'),
                    ),
                    const SizedBox(height: 20),

                    // Hata Mesajı
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Giriş/Kayıt Formu Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (_isSignUp) ...[
                                // First Name
                                TextFormField(
                                  controller: _firstNameController,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    labelText: 'First Name',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your first name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Last Name
                                TextFormField(
                                  controller: _lastNameController,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    labelText: 'Last Name',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your last name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Username
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: !_isLoading,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: const Icon(
                                      Icons.alternate_email,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  validator: _validateUsernameFormat,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'you@example.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@') ||
                                      !value.contains('.')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                enabled: !_isLoading,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                validator: _validatePassword,
                              ),

                              if (_isSignUp) ...[
                                const SizedBox(height: 16),
                                // Confirm Password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  enabled: !_isLoading,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  validator: _validateConfirmPassword,
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Login/Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : (_isSignUp ? _signUp : _signIn),
                                  icon: _isLoading
                                      ? Container(
                                          width: 24,
                                          height: 24,
                                          padding: const EdgeInsets.all(2.0),
                                          child:
                                              const CircularProgressIndicator(
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
                                              ? 'Creating Account...'
                                              : 'Logging in...')
                                        : (_isSignUp ? 'Sign Up' : 'Login'),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFB652),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),

                              if (!_isSignUp) ...[
                                const SizedBox(height: 5),
                                // Forgot Password
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
                                                _errorMessage =
                                                    'Please enter your email address first.';
                                              });
                                              return;
                                            }
                                            try {
                                              await _auth
                                                  .sendPasswordResetEmail(
                                                    email: _emailController.text
                                                        .trim(),
                                                  );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Password reset email sent. Please check your inbox.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              setState(() {
                                                _errorMessage =
                                                    'Could not send password reset email. Please try again.';
                                              });
                                            }
                                          },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 5),
                              // Divider
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // Toggle Login/Sign Up
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isSignUp
                                        ? "Already have an account? "
                                        : "Don't have an account? ",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isLoading ? null : _toggleMode,
                                    child: Text(
                                      _isSignUp ? 'Login' : 'Sign Up',
                                      style: const TextStyle(
                                        color: Color(0xFFEFB652),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isSignUp) const SizedBox(height: 20),

                    if (!_isSignUp) ...[
                      const SizedBox(height: 20),
                      // Sosyal Medya Butonları
                      _SocialLoginButton(
                        icon: FontAwesomeIcons.google,
                        text: 'Continue with Google',
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        onPressed: _isLoading ? null : _signInWithGoogle,
                      ),
                      if (showAppleSignIn) ...[
                        const SizedBox(height: 16),
                        _SocialLoginButton(
                          icon: FontAwesomeIcons.apple,
                          text: 'Continue with Apple',
                          backgroundColor: Colors.black,
                          textColor: Colors.white,
                          onPressed: _isLoading
                              ? null
                              : () => print('Continue with Apple'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _SocialLoginButton(
                        icon: FontAwesomeIcons.facebookF,
                        text: 'Continue with Facebook',
                        backgroundColor: Colors.blue[700]!,
                        onPressed: _isLoading
                            ? null
                            : () => print('Continue with Facebook'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  const _SocialLoginButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.onPressed,
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
