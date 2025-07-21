// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Font Awesome ikonları için

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Arka plan rengi
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // Üst boşluk
              // Logo ve Başlık
              Image.asset('assets/images/LogoBlackPNG.png', height: 250),
              

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
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none, // Kenarlık yok
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Şifre Giriş Alanı
                      TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none, // Kenarlık yok
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Giriş Butonu
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Giriş işlemleri burada yapılacak
                            print('Login button pressed');
                          },
                          icon: const Icon(Icons.arrow_forward_ios, size: 20),
                          label: const Text(
                            'Login',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFEFB652), // Mavi hex renk kodu
                            foregroundColor: Colors.white, // Buton yazı rengi
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0, // Gölgelendirme yok
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Şifremi Unuttum Metni
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Şifremi unuttum işlemleri
                            print('Forgot Password?');
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // VEYA Ayırıcı
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Sosyal Medya Butonları
              _SocialLoginButton(
                icon: FontAwesomeIcons.youtube,
                text: 'Continue with Youtube',
                backgroundColor: Colors.red[600]!,
                onPressed: () {
                  print('Continue with Youtube');
                },
              ),
              const SizedBox(height: 16),
              _SocialLoginButton(
                icon: FontAwesomeIcons.apple,
                text: 'Continue with Apple',
                backgroundColor: Colors.black,
                textColor: Colors.white,
                onPressed: () {
                  print('Continue with Apple');
                },
              ),
              const SizedBox(height: 16),
              _SocialLoginButton(
                icon: FontAwesomeIcons.facebookF,
                text: 'Continue with Facebook',
                backgroundColor: Colors.blue[700]!,
                onPressed: () {
                  print('Continue with Facebook');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Özel sosyal medya butonu widget'ı (private olduğu için bu dosyada kalabilir)
class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _SocialLoginButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, color: textColor),
        label: Text(
          text,
          style: TextStyle(fontSize: 18, color: textColor),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}