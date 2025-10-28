import 'package:flutter/material.dart';

/// Centralised design tokens inspired by the reference product mockups.
class WishLinkTheme {
  WishLinkTheme._();

  static const _primaryLight = Color(0xFFEFB652);
  static const _secondaryLight = Color(0xFFD34F0B);
  static const _surfaceLight = Color(0xFFE3E3E3);
  static const _textPrimaryLight = Color(0xFF323232);
  static const _textSecondaryLight = Color(0xFF9D9D9D);
  static const _errorLight = Color(0xFFD62032);
  static const _successLight = Color(0xFF34D97B);

  static const _primaryDark = Color(0xFFEFB652);
  static const _secondaryDark = Color(0xFFF2753A);
  static const _surfaceDark = Color(0xFF2A2A2A);
  static const _textPrimaryDark = Color(0xFFF2F2F2);
  static const _textSecondaryDark = Color(0xFFB5B5B5);
  static const _errorDark = Color(0xFFFF6B6B);
  static const _successDark = Color(0xFF4EE58E);

  static ThemeData light() {
    final textTheme = _buildTextTheme(
      baseColor: _textPrimaryLight,
      secondaryColor: _textSecondaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      fontFamily: 'HelveticaNeue',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _primaryLight,
        onPrimary: Colors.white,
        secondary: _secondaryLight,
        onSecondary: Colors.white,
        surface: _surfaceLight,
        onSurface: _textPrimaryLight,
        error: _errorLight,
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFF3F3F3),
        onSurfaceVariant: _textSecondaryLight,
        outline: Color(0xFFD5D5D5),
        outlineVariant: Color(0xFFEDEDED),
        shadow: Color(0x14000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF1E1E1E),
        onInverseSurface: Color(0xFFF2F2F2),
        inversePrimary: _primaryDark,
        tertiary: _successLight,
        onTertiary: Colors.black,
        tertiaryContainer: Color(0xFFE1F9EC),
        onTertiaryContainer: _textPrimaryLight,
        primaryContainer: Color(0xFFFFE7C4),
        onPrimaryContainer: _textPrimaryLight,
        secondaryContainer: Color(0xFFF6CDB5),
        onSecondaryContainer: _textPrimaryLight,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _textPrimaryLight,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.1),
        ),
        color: Colors.white,
        margin: const EdgeInsets.all(12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryLight,
          side: const BorderSide(color: _primaryLight, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryLight,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        labelStyle: textTheme.labelLarge!,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE4E4E4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD9D9D9), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _primaryLight, width: 1.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: _textSecondaryLight),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: _textSecondaryLight.withValues(alpha: 0.7),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 0,
        selectedItemColor: _primaryLight,
        unselectedItemColor: _textSecondaryLight.withValues(alpha: 0.7),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        tileColor: Colors.white,
      ),
      dividerColor: const Color(0xFFE0E0E0),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      extensions: const [WishLinkGradients.light()],
    );
  }

  static ThemeData dark() {
    final textTheme = _buildTextTheme(
      baseColor: _textPrimaryDark,
      secondaryColor: _textSecondaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      fontFamily: 'HelveticaNeue',
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: _primaryDark,
        onPrimary: Colors.black,
        secondary: _secondaryDark,
        onSecondary: Colors.black,
        surface: _surfaceDark,
        onSurface: _textPrimaryDark,
        error: _errorDark,
        onError: Colors.black,
        onSurfaceVariant: _textSecondaryDark,
        outline: Color(0xFF3A3A3A),
        outlineVariant: Color(0xFF2D2D2D),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFFFAFAFA),
        onInverseSurface: Color(0xFF1E1E1E),
        inversePrimary: _primaryLight,
        tertiary: _successDark,
        onTertiary: Colors.black,
        tertiaryContainer: Color(0xFF244531),
        onTertiaryContainer: _textPrimaryDark,
        primaryContainer: Color(0xFFEFB652),
        onPrimaryContainer: _textPrimaryDark,
        secondaryContainer: Color(0xFF692E15),
        onSecondaryContainer: _textPrimaryDark,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _textPrimaryDark,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        color: _surfaceDark,
        margin: const EdgeInsets.all(12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primaryDark,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryDark,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _secondaryDark,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceDark,
        labelStyle: textTheme.labelLarge!,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _primaryDark, width: 1.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: _textSecondaryDark),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: _textSecondaryDark.withValues(alpha: 0.6),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _surfaceDark.withValues(alpha: 0.95),
        elevation: 0,
        selectedItemColor: _primaryDark,
        unselectedItemColor: _textSecondaryDark.withValues(alpha: 0.7),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        tileColor: _surfaceDark,
      ),
      dividerColor: const Color(0xFF3A3A3A),
      dialogTheme: const DialogThemeData(
        backgroundColor: _surfaceDark,
        surfaceTintColor: Colors.transparent,
      ),
      extensions: const [WishLinkGradients.dark()],
    );
  }

  static TextTheme _buildTextTheme({
    required Color baseColor,
    required Color secondaryColor,
  }) {
    const baseFontSize = 14.0;

    TextStyle baseStyle(double size, FontWeight weight) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: 1.25,
      letterSpacing: -0.1,
    );

    return TextTheme(
      displayLarge: baseStyle(baseFontSize + 18, FontWeight.w700),
      displayMedium: baseStyle(baseFontSize + 12, FontWeight.w700),
      displaySmall: baseStyle(baseFontSize + 8, FontWeight.w700),
      headlineMedium: baseStyle(baseFontSize + 6, FontWeight.w700),
      headlineSmall: baseStyle(baseFontSize + 4, FontWeight.w600),
      titleLarge: baseStyle(baseFontSize + 4, FontWeight.w700),
      titleMedium: baseStyle(baseFontSize + 2, FontWeight.w600),
      titleSmall: baseStyle(baseFontSize + 1, FontWeight.w600),
      bodyLarge: baseStyle(baseFontSize + 1, FontWeight.w500),
      bodyMedium: baseStyle(
        baseFontSize,
        FontWeight.w500,
      ).copyWith(color: secondaryColor),
      bodySmall: baseStyle(
        baseFontSize - 1,
        FontWeight.w500,
      ).copyWith(color: secondaryColor.withValues(alpha: 0.9)),
      labelLarge: baseStyle(baseFontSize, FontWeight.w600),
      labelMedium: baseStyle(baseFontSize - 1, FontWeight.w600),
      labelSmall: baseStyle(baseFontSize - 2, FontWeight.w500),
    ).apply(
      bodyColor: baseColor,
      displayColor: baseColor,
      fontFamily: 'HelveticaNeue',
    );
  }
}

const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
  },
);

/// Theme extension used to surface gradient backgrounds across the app.
class WishLinkGradients extends ThemeExtension<WishLinkGradients> {
  final Gradient primary;
  final Gradient secondary;
  final Gradient tertiary;

  const WishLinkGradients({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  const WishLinkGradients.light()
    : this(
        primary: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4DC), Color(0xFFFDE9C9), Color(0xFFF9F1E7)],
        ),
        secondary: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6E7), Color(0xFFF8FDF9)],
        ),
        tertiary: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FCE6), Color(0xFFFEE7D2)],
        ),
      );

  const WishLinkGradients.dark()
    : this(
        primary: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312F29), Color(0xFF2A251C), Color(0xFF201C17)],
        ),
        secondary: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF26221B), Color(0xFF1C1A16)],
        ),
        tertiary: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E261F), Color(0xFF1F1B15)],
        ),
      );

  @override
  WishLinkGradients copyWith({
    Gradient? primary,
    Gradient? secondary,
    Gradient? tertiary,
  }) {
    return WishLinkGradients(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
    );
  }

  @override
  WishLinkGradients lerp(ThemeExtension<WishLinkGradients>? other, double t) {
    if (other is! WishLinkGradients) return this;

    Gradient lerpGradient(Gradient a, Gradient b) {
      if (a is LinearGradient && b is LinearGradient) {
        return LinearGradient(
          begin: AlignmentGeometry.lerp(a.begin, b.begin, t) ?? a.begin,
          end: AlignmentGeometry.lerp(a.end, b.end, t) ?? a.end,
          colors: List<Color>.generate(
            a.colors.length,
            (index) =>
                Color.lerp(
                  a.colors[index],
                  b.colors[index % b.colors.length],
                  t,
                ) ??
                a.colors[index],
          ),
          stops: a.stops,
        );
      }
      return a;
    }

    return WishLinkGradients(
      primary: lerpGradient(primary, other.primary),
      secondary: lerpGradient(secondary, other.secondary),
      tertiary: lerpGradient(tertiary, other.tertiary),
    );
  }
}
