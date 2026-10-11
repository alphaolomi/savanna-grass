import 'package:flutter/material.dart';

/// SavannaTime's design tokens (web/src/app/globals.css), with the brand's
/// own "positive" green standing in for its orange accent: same warm
/// neutrals, same ink, a green that already means "good time" in SavannaTime.
abstract final class Sv {
  // Light
  static const ground = Color(0xFFF2F2F0);
  static const surface = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF7F7F5);
  static const line = Color(0xFFE2E2DE);
  static const lineStrong = Color(0xFFD4D4CE);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6E6E68);
  static const green = Color(0xFF2F6F5E);
  static const greenDeep = Color(0xFF1F4D41);
  static const greenSoft = Color(0xFFE4EFEA);
  static const greenInk = Color(0xFF4F7F6C);
  static const sun = Color(0xFFE08A2E);
  static const sunSoft = Color(0xFFFBEEDC);
  static const negative = Color(0xFFD0342C);

  // Dark
  static const groundDark = Color(0xFF141413);
  static const surfaceDark = Color(0xFF1A1A1A);
  static const sunkenDark = Color(0xFF202020);
  static const lineDark = Color(0xFF2E2E2E);
  static const lineStrongDark = Color(0xFF3A3A38);
  static const inkDark = Color(0xFFF7F7F5);
  static const mutedDark = Color(0xFFA0A09A);
  static const greenDark = Color(0xFF5CBF9C);
  static const greenSoftDark = Color(0xFF16261F);
  static const greenInkDark = Color(0xFF8FD3BA);
  static const sunDark = Color(0xFFE5AB63);
  static const sunSoftDark = Color(0xFF2A2113);
  static const negativeDark = Color(0xFFE5695F);
}

/// Colours the Material scheme has no slot for: the hero gradient and the
/// colours drawn on top of it.
@immutable
class Savanna extends ThemeExtension<Savanna> {
  const Savanna({
    required this.heroTop,
    required this.heroBottom,
    required this.onHero,
    required this.onHeroMuted,
    required this.ring,
    required this.ringTrack,
    required this.sun,
  });

  final Color heroTop;
  final Color heroBottom;
  final Color onHero;
  final Color onHeroMuted;
  final Color ring;
  final Color ringTrack;
  final Color sun;

  static const light = Savanna(
    heroTop: Sv.green,
    heroBottom: Sv.greenDeep,
    onHero: Colors.white,
    onHeroMuted: Color(0xCCFFFFFF),
    ring: Color(0xFFBFE6D6),
    ringTrack: Color(0x33FFFFFF),
    sun: Sv.sun,
  );

  static const dark = Savanna(
    heroTop: Color(0xFF1C3A30),
    heroBottom: Sv.greenSoftDark,
    onHero: Sv.inkDark,
    onHeroMuted: Sv.greenInkDark,
    ring: Sv.greenDark,
    ringTrack: Color(0x22FFFFFF),
    sun: Sv.sunDark,
  );

  static Savanna of(BuildContext context) => Theme.of(context).extension<Savanna>()!;

  @override
  Savanna copyWith() => this;

  @override
  Savanna lerp(ThemeExtension<Savanna>? other, double t) =>
      (other is Savanna && t >= 0.5) ? other : this;
}

ThemeData savannaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Sv.greenDark,
          onPrimary: Color(0xFF0E1F18),
          primaryContainer: Sv.greenSoftDark,
          onPrimaryContainer: Sv.greenInkDark,
          secondary: Sv.sunDark,
          onSecondary: Color(0xFF2A1A05),
          secondaryContainer: Sv.sunSoftDark,
          onSecondaryContainer: Sv.sunDark,
          tertiary: Sv.greenInkDark,
          surface: Sv.groundDark,
          onSurface: Sv.inkDark,
          onSurfaceVariant: Sv.mutedDark,
          surfaceContainerLowest: Sv.groundDark,
          surfaceContainerLow: Sv.surfaceDark,
          surfaceContainer: Sv.sunkenDark,
          surfaceContainerHigh: Color(0xFF272726),
          surfaceContainerHighest: Sv.lineDark,
          outline: Sv.lineStrongDark,
          outlineVariant: Sv.lineDark,
          error: Sv.negativeDark,
        )
      : const ColorScheme.light(
          primary: Sv.green,
          onPrimary: Colors.white,
          primaryContainer: Sv.greenSoft,
          onPrimaryContainer: Sv.greenDeep,
          secondary: Sv.sun,
          onSecondary: Colors.white,
          secondaryContainer: Sv.sunSoft,
          onSecondaryContainer: Color(0xFF9A6420),
          tertiary: Sv.greenInk,
          surface: Sv.ground,
          onSurface: Sv.ink,
          onSurfaceVariant: Sv.muted,
          surfaceContainerLowest: Sv.surface,
          surfaceContainerLow: Sv.surface,
          surfaceContainer: Sv.sunken,
          surfaceContainerHigh: Color(0xFFEBEBE7),
          surfaceContainerHighest: Sv.line,
          outline: Sv.lineStrong,
          outlineVariant: Sv.line,
          error: Sv.negative,
        );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: text.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600),
    ),
    extensions: [dark ? Savanna.dark : Savanna.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Sv.greenSoftDark : Sv.greenDeep,
      contentTextStyle: TextStyle(color: dark ? Sv.greenInkDark : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
