import 'package:flutter/material.dart';

/// SavannaTime's productivity scale, as this app draws it. Labels are the
/// product's own (PRD level copy); null is uncategorized time, which has no
/// level and is never counted as neutral.
abstract final class Levels {
  /// Most productive first, the order every legend and bar uses.
  static const order = [2, 1, 0, -1, -2];

  static String label(int? level) => switch (level) {
    2 => 'Very productive',
    1 => 'Productive',
    0 => 'Neutral',
    -1 => 'Distracting',
    -2 => 'Very distracting',
    _ => 'Uncategorized',
  };

  static Color color(ColorScheme c, int? level) => switch (level) {
    2 => c.primary,
    1 => c.primary.withValues(alpha: 0.55),
    0 => c.outline,
    -1 => c.secondary,
    -2 => c.error,
    // Muted but visible on both themes; outlineVariant all but vanishes on
    // a dark card.
    _ => c.onSurfaceVariant.withValues(alpha: 0.4),
  };

  /// Category names as SavannaTime stores them, for display: `development`
  /// → `Development`.
  static String category(String name) =>
      name.isEmpty ? 'Uncategorized' : name[0].toUpperCase() + name.substring(1);
}
