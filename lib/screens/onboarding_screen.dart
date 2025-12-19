import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onContinue;

  const OnboardingScreen({super.key, required this.onContinue});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _totalSteps = 4;
  int _currentStep = 0;
  bool _isProcessing = false;
  String? _errorMessage;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handlePrimaryAction() async {
    if (_isProcessing) {
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      await _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _completeOnboarding();
  }

  Future<void> _handleSkip() async {
    if (_isProcessing) {
      return;
    }
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      await widget.onContinue();
    } catch (error, stackTrace) {
      debugPrint('Failed to complete onboarding: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _errorMessage = context.l10n.t('onboarding.error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
            _errorMessage = null;
          });
        },
        children: [
          _WishlistOnboardingSlide(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            isProcessing: _isProcessing,
            errorMessage: _errorMessage,
            onPrimaryAction: _handlePrimaryAction,
          ),
          _FriendsOnboardingSlide(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            isProcessing: _isProcessing,
            errorMessage: _errorMessage,
            onPrimaryAction: _handlePrimaryAction,
            onSkip: _handleSkip,
          ),
          _SecureOnboardingSlide(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            isProcessing: _isProcessing,
            errorMessage: _errorMessage,
            onPrimaryAction: _handlePrimaryAction,
            onSkip: _handleSkip,
          ),
          _HiddenReactionsOnboardingSlide(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            isProcessing: _isProcessing,
            errorMessage: _errorMessage,
            onPrimaryAction: _handlePrimaryAction,
            onSkip: _handleSkip,
          ),
        ],
      ),
    );
  }
}

class _WishlistOnboardingSlide extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onPrimaryAction;

  const _WishlistOnboardingSlide({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.isProcessing,
    required this.errorMessage,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF101622)
        : const Color(0xFFF7F8FA);

    return Container(
      color: backgroundColor,
      child: Stack(
        children: [
          _BackgroundOrbs(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 320,
                          height: MediaQuery.of(context).size.height * 0.48,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 320,
                              child: _PhoneMockup(isDark: isDark),
                            ),
                          ),
                        ),
                        const SizedBox(height: 70),
                        _HeroTexts(l10n: l10n),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        backgroundColor,
                        backgroundColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : onPrimaryAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 4,
                            shadowColor: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  l10n.t('onboarding.cta'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _OnboardingProgressIndicator(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsOnboardingSlide extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSkip;

  const _FriendsOnboardingSlide({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.isProcessing,
    required this.errorMessage,
    required this.onPrimaryAction,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = isDark
        ? [const Color(0xFF211B11), const Color(0xFF0F0F0F)]
        : [const Color(0xFFE0F2F1), const Color(0xFFE3F2FD)];

    final mediaPadding = MediaQuery.of(context).padding;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DotPatternPainter(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFF1B160E).withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: isProcessing ? null : onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? theme.colorScheme.primary
                              : const Color(0xFF997D4D),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.15,
                          ),
                        ),
                        child: Text(l10n.t('onboarding.skip')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 300),
                    child: Center(
                      child: SizedBox(
                        width: 320,
                        height: 320,
                        child: _FriendsArt(isDark: isDark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FriendsBottomCard(
              title: l10n.t('onboarding.followTitle'),
              subtitle: l10n.t('onboarding.followSubtitle'),
              onPrimaryAction: onPrimaryAction,
              isProcessing: isProcessing,
              errorMessage: errorMessage,
              currentStep: currentStep,
              totalSteps: totalSteps,
              bottomInset: mediaPadding.bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsBottomCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPrimaryAction;
  final bool isProcessing;
  final String? errorMessage;
  final int currentStep;
  final int totalSteps;
  final double bottomInset;

  const _FriendsBottomCard({
    required this.title,
    required this.subtitle,
    required this.onPrimaryAction,
    required this.isProcessing,
    required this.errorMessage,
    required this.currentStep,
    required this.totalSteps,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.7);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 40 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1B160E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isProcessing ? null : onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withValues(
                    alpha: 0.25,
                  ),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        context.l10n.t('onboarding.cta'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _OnboardingProgressIndicator(
              currentStep: currentStep,
              totalSteps: totalSteps,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecureOnboardingSlide extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSkip;

  const _SecureOnboardingSlide({
    required this.currentStep,
    required this.totalSteps,
    required this.isProcessing,
    required this.errorMessage,
    required this.onPrimaryAction,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final titlePrefix = l10n.t('onboarding.pinTitlePrefix');
    final titleHighlight = l10n.t('onboarding.pinTitleHighlight');
    final titleSuffix = l10n.t('onboarding.pinTitleSuffix');

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.45),
          radius: 1.2,
          colors: [Color(0xFF2E1A47), Color(0xFF1A1025), Color(0xFF0F0F12)],
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: isProcessing ? null : onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.8),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(l10n.t('onboarding.skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    const _SecureHeroArt(),
                    const SizedBox(height: 75),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        children: [
                          TextSpan(text: '$titlePrefix\n'),
                          TextSpan(
                            text: titleHighlight,
                            style: const TextStyle(color: Color(0xFFEFB652)),
                          ),
                          TextSpan(text: ' $titleSuffix'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.t('onboarding.pinSubtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0F0F12),
                    const Color(0xFF0F0F12).withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : onPrimaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                        shadowColor: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              l10n.t('onboarding.cta'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _OnboardingProgressIndicator(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: errorMessage!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenReactionsOnboardingSlide extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSkip;

  const _HiddenReactionsOnboardingSlide({
    required this.currentStep,
    required this.totalSteps,
    required this.isProcessing,
    required this.errorMessage,
    required this.onPrimaryAction,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF211B11), Color(0xFF1A1B24), Color(0xFF0F1016)],
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: isProcessing ? null : onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC8B592),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    child: Text(l10n.t('onboarding.skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _HiddenReactionsHero(),
                    const SizedBox(height: 75),
                    Text(
                      l10n.t('onboarding.hiddenTitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.t('onboarding.hiddenSubtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : onPrimaryAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 4,
                            shadowColor: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  l10n.t('onboarding.cta'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _OnboardingProgressIndicator(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecureHeroArt extends StatelessWidget {
  const _SecureHeroArt();

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFEFB652);
    final borderColor = Colors.white.withValues(alpha: 0.12);

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.person,
            size: 220,
            color: Colors.white.withValues(alpha: 0.14),
          ),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 120,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          Container(
            width: 190,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Icon(
                    Icons.redeem_outlined,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 42,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassLine(widthFactor: 0.7),
                        const SizedBox(height: 10),
                        _GlassLine(widthFactor: 1),
                        const SizedBox(height: 8),
                        _GlassLine(widthFactor: 0.85),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _GlassLine(widthFactor: 0.6)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2E1A47), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 35,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.lock, color: Color(0xFF0F0F12), size: 32),
            ),
          ),
          Positioned(
            top: 20,
            right: 40,
            child: _GlowDot(size: 10, color: accent),
          ),
          Positioned(
            bottom: 50,
            left: 50,
            child: _GlowDot(
              size: 8,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassLine extends StatelessWidget {
  final double widthFactor;

  const _GlassLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _NotificationChip extends StatelessWidget {
  final String text;

  const _NotificationChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            size: 18,
            color: Color(0xFFEFB652),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _OnboardingProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 30 : 10,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : (theme.brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _FriendsArt extends StatelessWidget {
  final bool isDark;

  const _FriendsArt({required this.isDark});

  static const _mainProfileUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDzGVDlrVOYFER7jeqU1VkHjKrGq_B8MHo_Ynw0t3XBP6AR9V93mDNAwc42w8eG7u1oyjIHUDsG9SAvNJ2jE4VGj1Af9nFgr0ZNRKkTklk4zt_ffRUMwDtc7d3C7-w5BPZK1bSvQ7xDo5frHm5Aye-cABQprmbYsR5CVweA1f62FSwZuarE5zbhe2NRif_uz6PySQtlFqoMI4949vwwP9as7TcrZp0C_TIVb8NBsa7vyPn6AkA_GtzitriG96zRtiK-J_3yhEh7qtA';
  static const _ahmetUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDGIxri2MQBhDJyTxm0fiRwbk0FZhoOo9BmvltnnVBHo1VXUz2kLpHHVg3tBseZwvnk6RxbJQnXKrXIHjgHuIsVZ_NbNVlSbOnbZt7LALiVFfAsyg8nI_7ofYuml78RF5fnQbo1gArvLZ8gx42qaHfGaDTLWppkcJBRN2HVq4oQ9z3Q1-iVNJuc7Vp8l8OfctwCCRp_m8ybaHE6CeZJDQuDn6tNqZJL671UgRd0sRdcmpoedm92l97TSUZ4h-Ioem9rWSLVTZnDYfI';
  static const _friendUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBuUHJnwj1kSBTC8UviH0ik3nq6LBIQ9Z_5etUb-I3Wum7zwaIcFCUVTT0nn9stoCeQuQXRe-0sdliUgUEyREUUiCFBSDETqigg16U6NezwGf8rbwlc_NJFcUHskKReaOu5YyrUl1HRTWYgMEbvOrIMz3RXDd6YpeS_gy4qtwIoW3gFj0jlv6S1eTmmi56D3aomVf7f3_MnTEM4wa3YGv862fpkKvZPICKHFARYJRfqgGA-6uA7bWPaFiC3jDTCSPeGHQjAsdKmeZY';
  static const _friendAltUrl =
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80';

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.3),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
                  blurRadius: 120,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: _MainProfileBubble(imageUrl: _mainProfileUrl, isDark: isDark),
        ),
        Positioned(
          left: -12,
          top: 36,
          child: _FriendActivityCard(
            name: 'Ahmet',
            message: 'Bir dilek ekledi',
            imageUrl: _ahmetUrl,
            isDark: isDark,
          ),
        ),
        Positioned(
          right: 10,
          top: 20,
          child: _FriendAvatarBubble(
            imageUrl: _friendUrl,
            size: 70,
            isDark: isDark,
            showBadge: true,
          ),
        ),
        Positioned(
          right: -18,
          bottom: 70,
          child: _FriendRequestCard(isDark: isDark),
        ),
      ],
    );
  }
}

class _HiddenReactionsHero extends StatelessWidget {
  const _HiddenReactionsHero();

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFEFB652);

    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 30,
            left: 50,
            right: 50,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [accent.withValues(alpha: 0.24), Colors.transparent],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 190,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x33FFFFFF), Color(0x11FFFFFF)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 90,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuC-Uefdxe0ICKXClkIm_dUts2qkq3Nqx1GmALKfGf55GKzuatXtpU2T9MmRs7NM_Yv5HTue5HZQUBS1xhM7fqNLEc8TeR3F7f_cJeXSDpHacwcp5b4cgTOIpEzoYAKPVOU8Ijwe1LzRtlSMjVEtgRLymYmDBvUmW-VWGErfBarFD24sZO3JT5xYlpQOM-eDFPOw-U4fFyhzSRxaX07UXZT71i1cb2LW9oYje_onjAGhks_Y8LgTFiJn40XpmWGkKWq9Z98GRJUTzy4',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 10,
                              width: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 8,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        child: const Icon(
                          Icons.visibility_off,
                          color: Colors.white70,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _ReactionBubble(
            alignment: Alignment(0.95, -0.55),
            backgroundColor: Color(0xFFEFB652),
            iconColor: Color(0xFF211B11),
            icon: Icons.favorite,
            rotation: 0.25,
          ),
          const _ReactionBubble(
            alignment: Alignment(-0.9, 0.0),
            backgroundColor: Colors.white,
            iconColor: Color(0xFFEFB652),
            icon: Icons.forum,
            rotation: -0.2,
          ),
          const _ReactionBadge(
            alignment: Alignment(-0.95, -0.2),
            icon: Icons.thumb_up,
            color: Color(0xFFEFB652),
          ),
          const _ReactionBadge(
            alignment: Alignment(0.9, 0.65),
            icon: Icons.sentiment_satisfied_alt,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _ReactionBubble extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double rotation;

  const _ReactionBubble({
    required this.alignment,
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final Color color;

  const _ReactionBadge({
    required this.alignment,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _MainProfileBubble extends StatelessWidget {
  final String imageUrl;
  final bool isDark;

  const _MainProfileBubble({required this.imageUrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.8),
          width: 5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipOval(child: Image.network(imageUrl, fit: BoxFit.cover)),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFB652),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendActivityCard extends StatelessWidget {
  final String name;
  final String message;
  final String imageUrl;
  final bool isDark;

  const _FriendActivityCard({
    required this.name,
    required this.message,
    required this.imageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x66211B11)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FriendAvatarBubble(
            imageUrl: imageUrl,
            size: 44,
            isDark: isDark,
            borderWidth: 2,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF1B160E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFEFB652),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  final bool isDark;

  const _FriendRequestCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x66211B11)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.person_add, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ayşe sana arkadaşlık isteği gönderdi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1B160E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '2 dakika önce',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendAvatarBubble extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool isDark;
  final bool showBadge;
  final double borderWidth;

  const _FriendAvatarBubble({
    required this.imageUrl,
    required this.size,
    required this.isDark,
    this.showBadge = false,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.6),
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(child: Image.network(imageUrl, fit: BoxFit.cover)),
          ),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFB652),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrbs extends StatelessWidget {
  final bool isDark;

  const _BackgroundOrbs({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFEFB652);
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -140,
              width: 320,
              height: 320,
              child: _BlurCircle(
                color: primary.withValues(alpha: isDark ? 0.25 : 0.15),
              ),
            ),
            Positioned(
              right: -100,
              bottom: 220,
              width: 280,
              height: 280,
              child: _BlurCircle(
                color: primary.withValues(alpha: isDark ? 0.2 : 0.12),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -40,
              width: 200,
              height: 200,
              child: _BlurCircle(
                color: Colors.tealAccent.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final Color color;

  const _BlurCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 160, spreadRadius: 40)],
      ),
    );
  }
}

class _HeroTexts extends StatelessWidget {
  final AppLocalizations l10n;

  const _HeroTexts({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1F1F1F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.t('onboarding.title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 25),
        Text(
          l10n.t('onboarding.subtitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.brightness == Brightness.dark
                ? Colors.grey.shade400
                : const Color(0xFF555555),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final bool isDark;

  const _PhoneMockup({required this.isDark});

  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBtViWWo9kkQj2xkGr-v4oyMPhu9fUF6ZUi8FYTPkNSQEouj7D6IzH975zCMDTGKc1Mj-7DIPYSMtijxnpm0UK2hnc5qEH14ZUI1r0ybYD_N_tKZYE9O7-uArIWjpoKuLNnXVScRLr865C3GVJ6zHXi-9YSJRPISiV7w0lPOR03wOeyExTqwOP5VgZG6PmgMbo7zkKkX2XGL5-ua0OsC5TwvnXTA97FWnGkMUMo0OU8ub-mVJ7ZxbjpnG3H0ddP6cOEFXHat-SUzF8';
  static const _wishImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDg2Q06sn4UXbEIi7-3xRBzwqWX5jgys2LFqNqIupIRGIbUWDHRJhDBfq5CcdAKrAUsZm2gykvyo1tWc2NoKtwzg9Uav2DrEYm1P8ro5GmEUQ5GqmEqeFHRbI2VcOIvi2O-pPp5Tfmo77B_oKXe_lAEwrUS2P3Gx57AggV-vWxUb_tp60Hib7W2jexX6sIyr2rWCIL7ghe5AsF7DCielpOBDJwAgGgCO9BI4helwo43jNM0K4bJqhmHlunwFxolNJUM1mY3bKgKU7Y';
  static const _secondaryWishImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAXeJwp4sTNIj2HUa5dJ9VUDJ75NlOjyy9gNW4YQzfHTu9sbI6mk0Ocn80CmGHFSUwme69X6Kcctdoi9JdIPZw1WzJk086SEwDlb2pxG6yc6ztT3zADSwguDyyJ34OM4trW4jqtqWn9Gg9vQYUBzKMsfXWNEsegsaiyZhxdzGRWp2lPaKlRiIJMzw4PaUh69tUgZ-u9nJ-Jn7e7X9PPL6KOCMtXVc6zVMzp7SPd17GL__oJS2-aLHYCLqxttb-lIAcF0KYKZ7RcNAc';

  @override
  Widget build(BuildContext context) {
    final phoneBorder = isDark ? const Color(0xFF232B3A) : Colors.white;
    final innerBackground = isDark
        ? const Color(0xFF0B0F17)
        : const Color(0xFFFCFCFC);

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: innerBackground,
              borderRadius: BorderRadius.circular(48),
              border: Border.all(color: phoneBorder, width: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 80,
                  right: 80,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 70,
                  right: 70,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 56, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.menu_rounded,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1F1F1F),
                          ),
                          const Spacer(),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(_avatarUrl, fit: BoxFit.cover),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'My Wishlist',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F1F1F),
                            ),
                      ),
                      Text(
                        '4 items • Public',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _HighlightedWishCard(
                        isDark: isDark,
                        imageUrl: _wishImageUrl,
                      ),
                      const SizedBox(height: 12),
                      _SkeletonWish(imageUrl: _secondaryWishImageUrl),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -22,
            right: -6,
            child: _FloatingBadge(
              icon: Icons.card_giftcard,
              backgroundColor: isDark ? const Color(0xFF1F2532) : Colors.white,
              iconColor: const Color(0xFFEFB652),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -10,
            child: _FloatingBadge(
              icon: Icons.auto_awesome,
              backgroundColor: isDark ? const Color(0xFF1F2532) : Colors.white,
              iconColor: Theme.of(context).colorScheme.primary,
              isCircular: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final bool isCircular;

  const _FloatingBadge({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isCircular ? 999 : 24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class _HighlightedWishCard extends StatelessWidget {
  final bool isDark;
  final String imageUrl;

  const _HighlightedWishCard({required this.isDark, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF151B26) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final accentColor = const Color(0xFFEFB652);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFFEFB652).withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vintage Camera',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Electronics',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '\$450',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFEFB652)
                        : const Color(0xFFB48228),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Visit Store',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: accentColor, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonWish extends StatelessWidget {
  final String imageUrl;

  const _SkeletonWish({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF151B26) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: MediaQuery.of(context).size.width * 0.25,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  final Color color;

  const _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
