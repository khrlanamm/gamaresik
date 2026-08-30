import 'package:flutter/material.dart';

/// Design tokens for GamaWaste.
///
/// [lightTheme] is the single Material 3 theme the app runs on; the bare
/// colour/text constants below it are the same tokens exposed for the places
/// that paint custom surfaces (gradient headers, category cards) where a
/// ColorScheme role would be the wrong abstraction.
class AppTheme {
  const AppTheme._();

  // ---------------------------------------------------------------- palette
  static const Color navyPrimary = Color(0xFF00426E);
  static const Color navySecondary = Color(0xFF003258);
  static const Color greenPrimary = Color(0xFF0CAA4E);
  static const Color greenSecondary = Color(0xFF09933F);
  static const Color lightGreen = Color(0xFF5FDEA0);
  static const Color yellow = Color(0xFFEAB308);
  static const Color red = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8FAFC);

  /// Muted foreground used for supporting copy. Deliberately darker than
  /// `Colors.grey` so body text keeps a ≥4.5:1 contrast ratio on white.
  static const Color textMuted = Color(0xFF5B6B7A);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  /// Accent used on navy surfaces (header captions, progress labels).
  static const Color onNavyMuted = Color(0xFFA5F3FC);

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyPrimary, navySecondary],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenPrimary, greenSecondary],
  );

  // ------------------------------------------------------------------ radii
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusPill = 28;

  // ------------------------------------------------------------------ theme
  static ColorScheme get colorScheme => ColorScheme.fromSeed(
        seedColor: greenPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: greenPrimary,
        onPrimary: Colors.white,
        secondary: navyPrimary,
        onSecondary: Colors.white,
        error: red,
        onError: Colors.white,
        surface: Colors.white,
        onSurface: navyPrimary,
        onSurfaceVariant: textMuted,
        outlineVariant: borderSubtle,
      );

  static ThemeData get lightTheme {
    final scheme = colorScheme;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(
        bodyColor: navyPrimary,
        displayColor: navyPrimary,
      ).copyWith(
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: navyPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: navyPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: navyPrimary,
        ),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: textMuted),
        bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: navyPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: navyPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: greenPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: greenPrimary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navyPrimary,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navyPrimary,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: navyPrimary,
        ),
        contentTextStyle: const TextStyle(fontSize: 14, height: 1.5, color: textMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navyPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: navyPrimary,
        textColor: navyPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: greenPrimary,
        linearTrackColor: borderSubtle,
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
    );
  }
}
