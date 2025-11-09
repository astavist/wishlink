// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wishlink/screens/login_screen.dart';
import 'package:wishlink/screens/home_screen.dart';
import 'package:wishlink/screens/email_verification_required_screen.dart';
import 'package:wishlink/screens/google_account_setup_screen.dart';
import 'package:wishlink/theme/theme_controller.dart';
import 'package:wishlink/locale/locale_controller.dart';
import 'package:wishlink/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final themeController = ThemeController();
  await themeController.loadThemeMode();
  final localeController = LocaleController();
  await localeController.loadPreferredLocale();
  runApp(
    MyApp(themeController: themeController, localeController: localeController),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.themeController,
    required this.localeController,
  });

  final ThemeController themeController;
  final LocaleController localeController;

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      );

  static const Color _seedColor = Color(0xFFEFB652);

  @override
  Widget build(BuildContext context) {
    return LocaleControllerProvider(
      controller: localeController,
      child: ThemeControllerProvider(
        controller: themeController,
        child: AnimatedBuilder(
          animation: Listenable.merge([themeController, localeController]),
          builder: (context, _) {
            return MaterialApp(
              title: 'WishLink',
              theme: _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              themeMode: themeController.themeMode,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                AppLocalizations.delegate,
              ],
              supportedLocales: LocaleController.supportedLocales,
              locale: localeController.locale,
              home: const AuthWrapper(),
              routes: {'/home': (context) => const HomeScreen()},
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor);
    return ThemeData(
      colorScheme: colorScheme.copyWith(primary: _seedColor),
      brightness: Brightness.light,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitionsTheme,
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: _seedColor),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      );
    return ThemeData(
      colorScheme: colorScheme.copyWith(primary: _seedColor),
      brightness: Brightness.dark,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitionsTheme,
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: _seedColor),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          return const EmailVerificationRequiredScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScaffold();
            }

            final data = userSnapshot.data?.data();
            final firstName = (data?['firstName'] as String?)?.trim() ?? '';
            final lastName = (data?['lastName'] as String?)?.trim() ?? '';
            final username = (data?['username'] as String?)?.trim() ?? '';

            final requiresProfile =
                data == null ||
                firstName.isEmpty ||
                lastName.isEmpty ||
                username.isEmpty;
            final isGoogleUser = _isGoogleProvider(user);

            if (isGoogleUser && requiresProfile) {
              final inferredFirstName = firstName.isNotEmpty
                  ? firstName
                  : _extractFirstName(user);
              final inferredLastName = lastName.isNotEmpty
                  ? lastName
                  : _extractLastName(user);
              final suggestion = _generateUsernameSuggestion(
                firstName: inferredFirstName,
                lastName: inferredLastName,
                email: user.email,
              );

              return _GoogleProfileGate(
                user: user,
                firstName: inferredFirstName,
                lastName: inferredLastName,
                email: user.email,
                suggestedUsername: suggestion,
                isNewUser: data == null,
              );
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _GoogleProfileGate extends StatefulWidget {
  final User user;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String suggestedUsername;
  final bool isNewUser;

  const _GoogleProfileGate({
    required this.user,
    this.firstName,
    this.lastName,
    this.email,
    required this.suggestedUsername,
    required this.isNewUser,
  });

  @override
  State<_GoogleProfileGate> createState() => _GoogleProfileGateState();
}

class _GoogleProfileGateState extends State<_GoogleProfileGate> {
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openProfileDialog();
    });
  }

  Future<void> _openProfileDialog() async {
    if (_dialogOpened || !mounted) {
      return;
    }
    _dialogOpened = true;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GoogleAccountSetupScreen(
          user: widget.user,
          firstName: widget.firstName,
          lastName: widget.lastName,
          email: widget.email,
          suggestedUsername: widget.suggestedUsername,
          isNewUser: widget.isNewUser,
          allowCancel: false,
        ),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == null || result.trim().isEmpty) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

Widget _buildLoadingScaffold() {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}

bool _isGoogleProvider(User user) {
  return user.providerData.any(
    (provider) => provider.providerId == 'google.com',
  );
}

String _extractFirstName(User user) {
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) {
    final parts = displayName.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      return parts.first;
    }
  }

  final emailPrefix = user.email?.split('@').first ?? '';
  if (emailPrefix.isNotEmpty) {
    return emailPrefix;
  }

  return 'wishlover';
}

String _extractLastName(User user) {
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) {
    final parts = displayName.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return parts.sublist(1).join(' ');
    }
  }
  return '';
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

  final suggestion = buffer.toString().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  if (suggestion.length >= 3) {
    return suggestion;
  }
  return 'wishlover${DateTime.now().millisecondsSinceEpoch % 1000}';
}
