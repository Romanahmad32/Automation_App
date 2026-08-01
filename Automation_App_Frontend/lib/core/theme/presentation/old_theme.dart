import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArchitecturalTheme {
  // --- 1. Shared Brand Colors ---
  static const Color primaryLight = Color(0xFF5461FE);
  static const Color primaryDimLight = Color(0xFF3F4CE0);

  // Brightened slightly for dark mode contrast
  static const Color primaryDark = Color(0xFF6B76FF);
  static const Color primaryDimDark = Color(0xFF5461FE);

  // --- 2. Light Theme Palette ---
  static const Color _lightSurfaceBase = Color(0xFF78729D); // Layer 1
  static const Color _lightSurfaceLow = Color(0xFF8680A8); // Layer 2
  static const Color _lightSurfaceLowest = Color(0xFF948EB3); // Layer 3 (Focus)
  static const Color _lightSurfaceHigh = Color(0xFF6B658D); // Input Base
  static const Color _lightSurfaceHighest = Color(0xFF5E587E); // Input Focus
  static const Color _lightOnSurface = Color(0xFF1E212B); // Slate-gray
  static const Color _lightOnSurfaceVariant = Color(0xFF4A4E5A);

  // --- 3. Dark Theme Palette ---
  static const Color _darkSurfaceBase = Color(
    0xFF16181D,
  ); // Deep Slate (Layer 1)
  static const Color _darkSurfaceLow = Color(0xFF1E222A); // Layer 2
  static const Color _darkSurfaceLowest = Color(0xFF272C38); // Layer 3 (Focus)
  static const Color _darkSurfaceHigh = Color(0xFF313746); // Input Base
  static const Color _darkSurfaceHighest = Color(0xFF3C4457); // Input Focus
  static const Color _darkOnSurface = Color(0xFFE4E6EB); // Off-white
  static const Color _darkOnSurfaceVariant = Color(
    0xFF9AA0B1,
  ); // Muted gray-blue

  // --- 4. Typography Factory ---
  // We extract this so both themes can use the exact same scale and font weights, just swapping the color.
  static TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      // The Editorial Voice (Manrope)
      displayLarge: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 32,
      ),
      headlineMedium: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.manrope(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),

      // The Functional Voice (Inter)
      bodyLarge: GoogleFonts.inter(
        color: onSurface,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: onSurface,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.inter(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        color: onSurface,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: GoogleFonts.inter(
        color: onSurface,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // --- 5. Light Theme ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightSurfaceBase,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        surface: _lightSurfaceBase,
        surfaceContainerLow: _lightSurfaceLow,
        surfaceContainerLowest: _lightSurfaceLowest,
        surfaceContainerHigh: _lightSurfaceHigh,
        surfaceContainerHighest: _lightSurfaceHighest,
        onSurface: _lightOnSurface,
        onSurfaceVariant: _lightOnSurfaceVariant,
        onPrimary: Colors.white,
        outlineVariant: Color.fromRGBO(30, 33, 43, 0.15),
      ),
      textTheme: _buildTextTheme(_lightOnSurface, _lightOnSurfaceVariant),
      inputDecorationTheme: _buildInputTheme(
        _lightSurfaceHigh,
        _lightSurfaceHighest,
        primaryDimLight,
        primaryLight,
        _lightOnSurfaceVariant,
      ),
      textButtonTheme: _buildTextButtonTheme(primaryLight, _lightSurfaceHigh),
      cardTheme: _buildCardTheme(_lightSurfaceLowest),
      dividerTheme: _buildDividerTheme(),
    );
  }

  // --- 6. Dark Theme ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkSurfaceBase,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        surface: _darkSurfaceBase,
        surfaceContainerLow: _darkSurfaceLow,
        surfaceContainerLowest: _darkSurfaceLowest,
        surfaceContainerHigh: _darkSurfaceHigh,
        surfaceContainerHighest: _darkSurfaceHighest,
        onSurface: _darkOnSurface,
        onSurfaceVariant: _darkOnSurfaceVariant,
        onPrimary: Colors.white,
        outlineVariant: Color.fromRGBO(
          228,
          230,
          235,
          0.15,
        ), // Ghost Border Dark
      ),
      textTheme: _buildTextTheme(_darkOnSurface, _darkOnSurfaceVariant),
      inputDecorationTheme: _buildInputTheme(
        _darkSurfaceHigh,
        _darkSurfaceHighest,
        primaryDimDark,
        primaryDark,
        _darkOnSurfaceVariant,
      ),
      textButtonTheme: _buildTextButtonTheme(primaryDark, _darkSurfaceHigh),
      cardTheme: _buildCardTheme(_darkSurfaceLowest),
      dividerTheme: _buildDividerTheme(),
    );
  }

  // --- 7. Reusable Component Builders ---

  static InputDecorationTheme _buildInputTheme(
    Color fill,
    Color focus,
    Color borderDim,
    Color borderActive,
    Color labelColor,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      focusColor: focus,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: const UnderlineInputBorder(borderSide: BorderSide.none),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: borderDim, width: 2),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: borderActive, width: 2),
      ),
      labelStyle: GoogleFonts.inter(color: labelColor),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(
    Color primaryColor,
    Color hoverSurface,
  ) {
    return TextButtonThemeData(
      style:
          TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return hoverSurface.withOpacity(0.5);
              }
              return Colors.transparent;
            }),
          ),
    );
  }

  static CardThemeData _buildCardTheme(Color cardColor) {
    return CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static DividerThemeData _buildDividerTheme() {
    return const DividerThemeData(
      color: Colors.transparent,
      space: 9.6,
      thickness: 0,
    );
  }

  // Ambient Shadows adapt based on theme
  static List<BoxShadow> ambientShadow(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? const Color.fromRGBO(0, 0, 0, 0.3) // Darker shadow for dark mode
            : const Color.fromRGBO(42, 52, 57, 0.08),
        offset: const Offset(0, 12),
        blurRadius: 32,
      ),
    ];
  }
}
