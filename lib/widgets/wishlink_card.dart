import 'package:flutter/material.dart';
import 'package:wishlink/theme/app_theme.dart';

/// Rounded pastel card aligned with the new WishLink design language.
class WishLinkCard extends StatelessWidget {
  const WishLinkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    this.margin = const EdgeInsets.symmetric(vertical: 12),
    this.gradient,
    this.onTap,
    this.heroTag,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final gradients = Theme.of(context).extension<WishLinkGradients>();
    final decoration = BoxDecoration(
      gradient: gradient ?? gradients?.secondary,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withOpacity(
          Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.12,
        ),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 12),
        ),
      ],
    );

    Widget content = Padding(padding: padding, child: child);

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }

    final card = Container(
      margin: margin,
      decoration: decoration,
      child: content,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}
