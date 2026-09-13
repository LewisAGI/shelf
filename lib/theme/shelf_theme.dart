import 'package:flutter/material.dart';

/// White canvas, orange chrome. Primary here means the app surface,
/// not Material `ColorScheme.primary` (which stays orange so buttons work).
class ShelfColors {
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFFFFFF);
  static const orange = Color(0xFFF15A22);
  static const orangePressed = Color(0xFFD14A18);
  static const orangeSoft = Color(0xFFFFE8DE);
  static const ink = Color(0xFF1C1917);
  static const muted = Color(0xFF78716C);
  static const hairline = Color(0xFFE7E5E4);
  static const defaultOrangeHex = '#F15A22';
  static const defaultPurpleHex = '#6D28D9';

  /// Grok-style dark chat pill (intentional even on white Shelf chrome).
  static const composerPill = Color(0xFF1C1C1E);
  static const composerMicCircle = Color(0xFF3A3A3C);
  static const composerHint = Color(0xFF8E8E93);
  static const composerText = Color(0xFFF5F5F7);
  static const composerCaret = Color(0xFF0A84FF);
}

class ShelfTheme {
  static ThemeData light() {
    const orange = ShelfColors.orange;
    final scheme = ColorScheme.light(
      primary: orange,
      onPrimary: ShelfColors.white,
      secondary: orange,
      onSecondary: ShelfColors.white,
      surface: ShelfColors.white,
      onSurface: ShelfColors.ink,
      surfaceContainerHighest: const Color(0xFFF5F5F4),
      outline: ShelfColors.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ShelfColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: ShelfColors.white,
        foregroundColor: ShelfColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ShelfColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ShelfColors.orange),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ShelfColors.orange,
        foregroundColor: ShelfColors.white,
        elevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ShelfColors.white,
        indicatorColor: ShelfColors.orangeSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? ShelfColors.orange : ShelfColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? ShelfColors.orange : ShelfColors.muted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: ShelfColors.orangeSoft,
        backgroundColor: const Color(0xFFF5F5F4),
        side: const BorderSide(color: ShelfColors.hairline),
        labelStyle: const TextStyle(color: ShelfColors.ink),
        secondaryLabelStyle: const TextStyle(color: ShelfColors.orange),
        checkmarkColor: ShelfColors.orange,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ShelfColors.orange,
          foregroundColor: ShelfColors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ShelfColors.orange,
          side: const BorderSide(color: ShelfColors.orange),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ShelfColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ShelfColors.orange, width: 1.5),
        ),
      ),
      dividerColor: ShelfColors.hairline,
      splashColor: ShelfColors.orangeSoft,
    );
  }
}
