import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';

// Light + dark themes for the Lokinter app.
// Headings use Bricolage Grotesque, the rest uses Poppins — same pairing as the site.
class LokinterTheme {
  LokinterTheme._();

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    secondary: AppPalette.navy,
    onSecondary: Colors.white,
    error: Color(0xFFD64545),
    onError: Colors.white,
    surface: Color(0xFFFFFFFF),
    onSurface: AppPalette.navy,
    surfaceContainerHighest: Color(0xFFF4F5F7), // input fills
    onSurfaceVariant: Color(0xFF6E7080), // muted text
    outline: Color(0xFFE3E5EC),
    outlineVariant: Color(0xFFEDEEF2),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    secondary: AppPalette.softAccent,
    onSecondary: AppPalette.deepNavy,
    error: Color(0xFFE57373),
    onError: Colors.black,
    surface: Color(0xFF1A1B20),
    onSurface: Color(0xFFF3F4F7),
    surfaceContainerHighest: Color(0xFF23252B),
    onSurfaceVariant: Color(0xFF9A9CA6),
    outline: Color(0xFF2E3038),
    outlineVariant: Color(0xFF24262C),
  );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final screenBg = isDark ? const Color(0xFF0F1012) : const Color(0xFFFFFFFE);

    final text = GoogleFonts.poppinsTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final headingFont = GoogleFonts.bricolageGrotesque(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: screenBg,
      textTheme: text.copyWith(
        displaySmall: headingFont.copyWith(fontSize: 28),
        headlineMedium: headingFont.copyWith(fontSize: 24),
        headlineSmall: headingFont.copyWith(fontSize: 20),
        titleLarge: headingFont.copyWith(fontSize: 18),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: screenBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: AppPalette.primary,
        ),
      ),
      dividerColor: scheme.outline,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: _fieldBorder(scheme.outline),
        enabledBorder: _fieldBorder(scheme.outline),
        focusedBorder: _fieldBorder(AppPalette.primary, width: 1.4),
        errorBorder: _fieldBorder(scheme.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
