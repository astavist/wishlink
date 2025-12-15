import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:wishlink/screens/login_screen.dart';
import 'package:wishlink/locale/locale_controller.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/services/notification_service.dart';

class EmailVerificationRequiredScreen extends StatefulWidget {
  const EmailVerificationRequiredScreen({super.key});

  @override
  State<EmailVerificationRequiredScreen> createState() =>
      _EmailVerificationRequiredScreenState();
}

class _EmailVerificationRequiredScreenState
    extends State<EmailVerificationRequiredScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isResending = false;
  Timer? _verificationTimer;
  bool _isDisposed = false; // Disposed flag ekle
  Locale? _appliedLocale;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    // Otomatik email gönderme kaldırıldı - sadece kullanıcı resend butonuna bastığında gidecek
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeController = LocaleControllerProvider.of(context);
    final locale = localeController.locale;
    if (_appliedLocale != locale) {
      _appliedLocale = locale;
      _setFirebaseLocale(locale);
    }
  }

  void _setFirebaseLocale(Locale locale) {
    try {
      // Update Firebase Auth locale for verification emails
      final languageCode = locale.languageCode.toLowerCase() == 'tr'
          ? 'tr'
          : 'en';
      _auth.setLanguageCode(languageCode);
    } catch (e) {
      print('Firebase locale set error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Flag'i set et
    _stopVerificationCheck();
    super.dispose();
  }

  void _startVerificationCheck() {
    // Timer'ı temizle (eğer zaten çalışıyorsa)
    _verificationTimer?.cancel();

    // Her 3 saniyede bir email verifikasyonunu kontrol et
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      // Disposed flag kontrolü
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      try {
        // Disposed flag kontrolü (async işlem öncesi)
        if (_isDisposed || !mounted) {
          timer.cancel();
          return;
        }

        await _auth.currentUser?.reload();

        // Disposed flag kontrolü (async işlem sonrası)
        if (_isDisposed || !mounted) {
          timer.cancel();
          return;
        }

        if (_auth.currentUser?.emailVerified == true) {
          timer.cancel();
          // Email verifikasyonu tamamlandı, Firestore'u güncelle
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .update({'emailVerified': true});

          if (mounted && !_isDisposed) {
            // Otomatik olarak HomeScreen'e yönlendir
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } catch (e) {
        // Hata durumunda timer'ı durdur
        timer.cancel();
        if (!_isDisposed) {
          print('Verification check error: $e');
        }
      }
    });
  }

  void _stopVerificationCheck() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
  }

  Future<void> _resendVerificationEmail() async {
    if (_isDisposed) return; // Disposed kontrolü

    final l10n = context.l10n;

    setState(() {
      _isResending = true;
    });

    try {
      if (_isDisposed) return; // Disposed kontrolü
      await _auth.currentUser?.sendEmailVerification();

      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('emailVerification.resendSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t('emailVerification.resendError', params: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    // Önce flag'i set et
    _isDisposed = true;

    // Timer'ı durdur
    _stopVerificationCheck();

    // Çıkış yap
    await NotificationService.instance.signOutWithCleanup(_auth);

    // Navigate (mounted kontrolü gerekli değil çünkü zaten disposed)
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: const Text(''), // Boş title
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _handleSignOut,
            child: Text(
              l10n.t('common.backToLogin'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              l10n.t('emailVerification.title'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t(
                'emailVerification.subtitle',
                params: {'email': _auth.currentUser?.email ?? ''},
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.t('emailVerification.instructions'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResending ? null : _resendVerificationEmail,
                child: _isResending
                    ? const CircularProgressIndicator()
                    : Text(l10n.t('emailVerification.sendButton')),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('emailVerification.postSendInfo'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _handleSignOut,
              child: Text(
                l10n.t('common.useDifferentAccount'),
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
