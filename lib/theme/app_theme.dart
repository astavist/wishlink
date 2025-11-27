import 'package:flutter/material.dart';

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
