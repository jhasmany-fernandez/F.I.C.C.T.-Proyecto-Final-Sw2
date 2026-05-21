import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Tema visual de Wireless HeatMapper.
///
/// - Material 3 con seed [kSeedColor].
/// - Tipografía: **Poppins** para títulos / **Inter** para cuerpo.
/// - Soporta light + dark, alternados por `themeMode: ThemeMode.system`.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
    );

    final textTheme = _buildTextTheme(base.textTheme, colorScheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: colorScheme.onInverseSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        extendedTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Combina Inter (cuerpo) + Poppins (títulos) sobre el [TextTheme] base.
  static TextTheme _buildTextTheme(TextTheme base, ColorScheme scheme) {
    final body = GoogleFonts.interTextTheme(base).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    Color titleColor = scheme.onSurface;

    return body.copyWith(
      displayLarge: GoogleFonts.poppins(
        textStyle: body.displayLarge,
        fontWeight: FontWeight.w700,
        color: titleColor,
      ),
      displayMedium: GoogleFonts.poppins(
        textStyle: body.displayMedium,
        fontWeight: FontWeight.w700,
        color: titleColor,
      ),
      displaySmall: GoogleFonts.poppins(
        textStyle: body.displaySmall,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
      headlineLarge: GoogleFonts.poppins(
        textStyle: body.headlineLarge,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
      headlineMedium: GoogleFonts.poppins(
        textStyle: body.headlineMedium,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
      headlineSmall: GoogleFonts.poppins(
        textStyle: body.headlineSmall,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle: body.titleLarge,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
      titleMedium: GoogleFonts.poppins(
        textStyle: body.titleMedium,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
    );
  }
}
