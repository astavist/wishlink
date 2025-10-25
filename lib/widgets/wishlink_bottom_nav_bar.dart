import 'package:flutter/material.dart';

/// Decorative wrapper that applies the curved pill background used in the
/// reference design to any bottom navigation content.
class WishLinkBottomNavBar extends StatelessWidget {
  const WishLinkBottomNavBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundBase =
        theme.bottomNavigationBarTheme.backgroundColor ??
        (isDark ? colorScheme.surface : Colors.white);

    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundBase.withOpacity(isDark ? 0.88 : 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.transparent, width: 0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 18),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    );
  }
}
