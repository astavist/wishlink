// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
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

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Colors.grey[400]!, Colors.white],
          ),
        ),
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Logo ve Başlık
                  Image.asset('assets/images/LogoBlackPNG.png', height: 200),

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

                  // Giriş Kutusu (Card)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // E-posta Giriş Alanı
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            enabled: !_isLoading,
                            readOnly: false,
                            keyboardType: TextInputType.emailAddress,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () {
                              _passwordFocusNode.requestFocus();
                            },
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                                horizontal: 12.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Şifre Giriş Alanı
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_isLoading,
                            readOnly: false,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onEditingComplete: _signIn,
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                                horizontal: 12.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Giriş Butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _signIn,
                              icon: _isLoading
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 20,
                                    ),
                              label: Text(
                                _isLoading ? 'Logging in...' : 'Login',
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
                          const SizedBox(height: 16),
                          // Şifremi Unuttum Metni
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
                                        await _auth.sendPasswordResetEmail(
                                          email: _emailController.text.trim(),
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
                          const SizedBox(height: 5),
                          // VEYA Ayırıcı
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Sosyal Medya Butonları
                  _SocialLoginButton(
                    icon: FontAwesomeIcons.google,
                    text: 'Continue with Google',
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    onPressed: _isLoading
                        ? null
                        : () => print('Continue with Google'),
                  ),
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
  final VoidCallback? onPressed; // VoidCallback'i nullable yap

  const _SocialLoginButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.onPressed, // required kaldır
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed, // Direkt olarak onPressed'ı geç
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
