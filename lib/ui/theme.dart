import 'package:flutter/material.dart';

/// Savanna palette: acacia green, dry-grass gold, sunset terracotta.
const grassGreen = Color(0xFF3F7D3A);
const dryGrass = Color(0xFFD9A441);
const sunset = Color(0xFFC8553D);

ThemeData savannaTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: grassGreen,
    brightness: brightness,
    secondary: dryGrass,
    tertiary: sunset,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
