import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme-Familie "Variante A" (Kanzlei-Design): warmes Bordeaux-Markenbild auf
/// cremefarbenem Grund, mit den Schriften Jost (UI/Titel), Source Sans 3
/// (Fließtext) und Source Serif 4 (große Überschriften).
///
/// Wiederverwendet bewusst den Theme-Builder [MaterialTheme.theme]: dadurch
/// teilen sich Kanzlei- und Standard-Design dieselben Komponenten-Stile
/// (Karten, Eingabefelder, Buttons) und unterscheiden sich nur in Farben und
/// Typografie.
class KanzleiMaterialTheme extends MaterialTheme {
  const KanzleiMaterialTheme(super.textTheme);

  @override
  ThemeData light() => theme(KanzleiPalette.lightScheme());

  @override
  ThemeData dark() => theme(KanzleiPalette.darkScheme());
}

/// Baut die Schrift-Skala des Kanzlei-Designs: serifenbetonte Display-/Headline-
/// Stile (Source Serif 4), Jost für Titel/Labels (Buttons, App-Bar, Navigation)
/// und Source Sans 3 für den Fließtext.
TextTheme createKanzleiTextTheme(BuildContext context) {
  final base = Theme.of(context).textTheme;
  final serif = GoogleFonts.sourceSerif4TextTheme(base);
  final ui = GoogleFonts.jostTextTheme(base);
  final body = GoogleFonts.sourceSans3TextTheme(base);

  return base.copyWith(
    displayLarge: serif.displayLarge,
    displayMedium: serif.displayMedium,
    displaySmall: serif.displaySmall,
    headlineLarge: serif.headlineLarge,
    headlineMedium: serif.headlineMedium,
    headlineSmall: serif.headlineSmall,
    titleLarge: ui.titleLarge,
    titleMedium: ui.titleMedium,
    titleSmall: ui.titleSmall,
    labelLarge: ui.labelLarge,
    labelMedium: ui.labelMedium,
    labelSmall: ui.labelSmall,
    bodyLarge: body.bodyLarge,
    bodyMedium: body.bodyMedium,
    bodySmall: body.bodySmall,
  );
}

/// Die Bordeaux-Farbpalette für Hell- und Dunkelmodus. Die Surface-Abstufungen
/// sind so gewählt, dass [MaterialTheme.theme] daraus Hintergrund (Page),
/// Karten (weiß) und gefüllte Felder mit jeweils einem Kontrastschritt ableitet.
abstract final class KanzleiPalette {
  static const Color _bordeaux = Color(0xFF5E2028);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: _bordeaux,
      surfaceTint: _bordeaux,
      onPrimary: Color(0xFFF7F1EC),
      primaryContainer: Color(0xFFF0E2DD),
      onPrimaryContainer: Color(0xFF4A181E),
      secondary: Color(0xFF6E6360),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFEFE7E1),
      onSecondaryContainer: Color(0xFF2A2326),
      tertiary: Color(0xFF8A6D12),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFBF1D8),
      onTertiaryContainer: Color(0xFF5A4A10),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFFBF8F4),
      onSurface: Color(0xFF2A2326),
      onSurfaceVariant: Color(0xFF7A6F6E),
      outline: Color(0xFFB7AAA3),
      outlineVariant: Color(0xFFE6DED7),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF322B2D),
      onInverseSurface: Color(0xFFF6EEEA),
      inversePrimary: Color(0xFFE5A9B0),
      primaryFixed: Color(0xFFF0E2DD),
      onPrimaryFixed: Color(0xFF2B0A0E),
      primaryFixedDim: Color(0xFFE5A9B0),
      onPrimaryFixedVariant: Color(0xFF5E2028),
      secondaryFixed: Color(0xFFEFE7E1),
      onSecondaryFixed: Color(0xFF241E1C),
      secondaryFixedDim: Color(0xFFD6C7C2),
      onSecondaryFixedVariant: Color(0xFF564B48),
      tertiaryFixed: Color(0xFFFBF1D8),
      onTertiaryFixed: Color(0xFF2A2000),
      tertiaryFixedDim: Color(0xFFE8CE86),
      onTertiaryFixedVariant: Color(0xFF6B5512),
      surfaceDim: Color(0xFFE7E1DA),
      surfaceBright: Color(0xFFFBF8F4),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F3EE),
      surfaceContainer: Color(0xFFF4EFEA),
      surfaceContainerHigh: Color(0xFFF1EBE5),
      surfaceContainerHighest: Color(0xFFECE4DE),
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFE5A9B0),
      surfaceTint: Color(0xFFE5A9B0),
      onPrimary: Color(0xFF44121A),
      primaryContainer: Color(0xFF5E2028),
      onPrimaryContainer: Color(0xFFF4D9DC),
      secondary: Color(0xFFD6C7C2),
      onSecondary: Color(0xFF3A302E),
      secondaryContainer: Color(0xFF4A403D),
      onSecondaryContainer: Color(0xFFEFE3DE),
      tertiary: Color(0xFFE8CE86),
      onTertiary: Color(0xFF3F3100),
      tertiaryContainer: Color(0xFF6B5512),
      onTertiaryContainer: Color(0xFFFBEFC9),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF1A1416),
      onSurface: Color(0xFFEDE2E0),
      onSurfaceVariant: Color(0xFFCDBFBC),
      outline: Color(0xFF8C7E7B),
      outlineVariant: Color(0xFF463C3A),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFEDE2E0),
      onInverseSurface: Color(0xFF322B2D),
      inversePrimary: Color(0xFF5E2028),
      primaryFixed: Color(0xFFF0E2DD),
      onPrimaryFixed: Color(0xFF2B0A0E),
      primaryFixedDim: Color(0xFFE5A9B0),
      onPrimaryFixedVariant: Color(0xFF5E2028),
      secondaryFixed: Color(0xFFEFE7E1),
      onSecondaryFixed: Color(0xFF241E1C),
      secondaryFixedDim: Color(0xFFD6C7C2),
      onSecondaryFixedVariant: Color(0xFF564B48),
      tertiaryFixed: Color(0xFFFBF1D8),
      onTertiaryFixed: Color(0xFF2A2000),
      tertiaryFixedDim: Color(0xFFE8CE86),
      onTertiaryFixedVariant: Color(0xFF6B5512),
      surfaceDim: Color(0xFF1A1416),
      surfaceBright: Color(0xFF413A3B),
      surfaceContainerLowest: Color(0xFF120D0F),
      surfaceContainerLow: Color(0xFF221B1D),
      surfaceContainer: Color(0xFF261F21),
      surfaceContainerHigh: Color(0xFF2F2729),
      surfaceContainerHighest: Color(0xFF3A3133),
    );
  }
}
