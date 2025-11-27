// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wishlink/screens/login_screen.dart';
import 'package:wishlink/screens/home_screen.dart';
import 'package:wishlink/screens/email_verification_required_screen.dart';
import 'package:wishlink/screens/account_setup_screen.dart';
import 'package:wishlink/theme/theme_controller.dart';
import 'package:wishlink/locale/locale_controller.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();
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
      fontFamily: 'Geist',
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitionsTheme,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _seedColor,
      ),
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
      fontFamily: 'Geist',
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitionsTheme,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _seedColor,
      ),
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checkingRemoteAuthState = true;

  @override
  void initState() {
    super.initState();
    _refreshAuthState();
  }

  Future<void> _refreshAuthState() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _checkingRemoteAuthState = false;
        });
      }
      return;
    }

    try {
      // Reload to ensure deletions/disablements made from Firebase console take effect.
      await user.reload();
      if (mounted && auth.currentUser == null) {
        await auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      if (_shouldForceLogout(e.code)) {
        await auth.signOut();
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingRemoteAuthState = false;
        });
      }
    }
  }

  bool _shouldForceLogout(String code) {
    return code == 'user-not-found' ||
        code == 'user-disabled' ||
        code == 'user-token-expired' ||
        code == 'invalid-user-token';
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRemoteAuthState) {
      return _buildLoadingScaffold();
    }

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

            final userDoc = userSnapshot.data;
            final docExists = userDoc?.exists ?? false;
            final data = userDoc?.data();
            final firstName = (data?['firstName'] as String?)?.trim() ?? '';
            final lastName = (data?['lastName'] as String?)?.trim() ?? '';
            final username = (data?['username'] as String?)?.trim() ?? '';
            final isAuthorized = data?['isAuthorized'] as bool? ?? true;
            final isGoogleUser = _isGoogleProvider(user);
            final isAppleUser = _isAppleProvider(user);

            if (!isAuthorized) {
              return const _ForcedLogoutView();
            }

            if (!docExists && !_isNewlyCreatedUser(user)) {
              return const _ForcedLogoutView();
            }

            final requiresProfile =
                data == null ||
                firstName.isEmpty ||
                lastName.isEmpty ||
                username.isEmpty;

            if ((isGoogleUser || isAppleUser) && requiresProfile) {
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
              return _ProfileCompletionGate(
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

  bool _isNewlyCreatedUser(User user) {
    final creationTime = user.metadata.creationTime;
    if (creationTime == null) {
      return false;
    }
    return DateTime.now().difference(creationTime) < const Duration(minutes: 5);
  }
}

class _ProfileCompletionGate extends StatefulWidget {
  final User user;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String suggestedUsername;
  final bool isNewUser;

  const _ProfileCompletionGate({
    required this.user,
    this.firstName,
    this.lastName,
    this.email,
    required this.suggestedUsername,
    required this.isNewUser,
  });

  @override
  State<_ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}

class _ProfileCompletionGateState extends State<_ProfileCompletionGate> {
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
        builder: (_) => AccountSetupScreen(
          user: widget.user,
          firstName: widget.firstName,
          lastName: widget.lastName,
          email: widget.email,
          suggestedUsername: widget.suggestedUsername,
          isNewUser: widget.isNewUser,
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

class _ForcedLogoutView extends StatefulWidget {
  const _ForcedLogoutView({super.key});

  @override
  State<_ForcedLogoutView> createState() => _ForcedLogoutViewState();
}

class _ForcedLogoutViewState extends State<_ForcedLogoutView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAuth.instance.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildLoadingScaffold();
  }
}

bool _isGoogleProvider(User user) {
  return user.providerData.any(
    (provider) => provider.providerId == 'google.com',
  );
}

bool _isAppleProvider(User user) {
  return user.providerData.any(
    (provider) => provider.providerId == 'apple.com',
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
