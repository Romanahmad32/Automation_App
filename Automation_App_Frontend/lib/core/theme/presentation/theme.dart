import "package:automation_app/core/theme/domain/schriftstufe.dart";
import "package:flutter/material.dart";

import "auswahl_themes.dart";
import "extended_color.dart";
import "schriftskala.dart";
import "theme_schemes_dark.dart";
import "theme_schemes_light.dart";

export "extended_color.dart";

class MaterialTheme {
  final TextTheme textTheme;

  /// Der gewählte Schriftgrad (Issue #57). Als Feld und nicht als Konstante,
  /// weil die Wahl in den Einstellungen liegt: `main.dart` baut das Theme neu,
  /// sobald der `ThemeBloc` eine andere Stufe meldet. Der Vorgabewert hält
  /// jeden Aufrufer am Leben, der die Stufe nicht kennt — vor allem die Tests.
  final Schriftstufe schriftstufe;

  const MaterialTheme(
    this.textTheme, {
    this.schriftstufe = Schriftstufe.vorgabe,
  });

  ThemeData light() => theme(LightSchemes.standard());

  ThemeData lightMediumContrast() => theme(LightSchemes.mediumContrast());

  ThemeData lightHighContrast() => theme(LightSchemes.highContrast());

  ThemeData dark() => theme(DarkSchemes.standard());

  ThemeData darkMediumContrast() => theme(DarkSchemes.mediumContrast());

  ThemeData darkHighContrast() => theme(DarkSchemes.highContrast());

  ThemeData theme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;

    // Drei abgestufte Flächen, damit Karten sichtbar über dem Hintergrund
    // „schweben" und gefüllte Felder sich wiederum von der Karte abheben.
    // Im Hellmodus sind Karten heller als der Grund (weiß auf hellgrau),
    // im Dunkelmodus heller als der dunkle Grund — in beiden Fällen ein Schritt
    // Kontrast, ohne grell zu wirken.
    final scaffoldBg = isLight
        ? colorScheme.surfaceContainerLow
        : colorScheme.surface;
    final cardColor = isLight
        ? colorScheme.surfaceContainerLowest
        : colorScheme.surfaceContainerHigh;
    final fieldFill = isLight
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerHighest;

    // Zuerst der Schriftgrad: [Schriftskala.anheben] hebt jede Rolle um den
    // Zuschlag der gewählten [schriftstufe] an (Issue #57). Der Aufruf steht
    // hier und nicht in den beiden Theme-Familien, weil jede von ihnen durch
    // diese Methode läuft — eine Stelle, vier Fassungen (Standard/Kanzlei ×
    // hell/dunkel). Danach die Farben und etwas kräftigere Überschriften für
    // klare Hierarchie (App- und Sektionstitel), Fließtext bleibt unverändert.
    final baseText = Schriftskala.anheben(textTheme, schriftstufe).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final styledText = baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    const radius = 12.0;
    OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      textTheme: styledText,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: colorScheme.surface,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      // Karten mit feinem Rahmen, weichem Schatten und größerem Radius, damit
      // jede Sektion als eigenständige Fläche lesbar ist statt mit dem
      // Hintergrund zu verschwimmen.
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isLight ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: styledText.titleLarge,
        // Feine Trennlinie zum Inhalt, ersetzt den fehlenden Schatten.
        shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          // Nur das Gewicht, keine Größe: Hier stand bis Issue #57 ein festes
          // `fontSize: 15`, das den Knopf von der Skala abgekoppelt hätte.
          // Der angehobene `labelLarge` trägt ihn selbst.
          textStyle: styledText.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Ausgewählt trägt über Form und Farbe, nicht über Farbe allein —
      // die Begründung und die gemessenen Kontraste stehen in
      // [AuswahlThemes].
      segmentedButtonTheme: AuswahlThemes.segmentierteSchaltflaeche(
        colorScheme,
      ),
      chipTheme: AuswahlThemes.chips(colorScheme, styledText),
      // Gefüllte, kompakte Eingabefelder mit ruhigem Rahmen. Der Rahmen wird
      // erst beim Fokus kräftig (primär), Fehler bleiben immer rot (s. u.).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: fieldBorder(colorScheme.outlineVariant),
        enabledBorder: fieldBorder(colorScheme.outlineVariant),
        focusedBorder: fieldBorder(colorScheme.primary, width: 2),
        // Material-3-Standard färbt den Rahmen eines fehlerhaften Outline-Felds
        // beim Hovern mit `onErrorContainer` ein — im Light-Theme nahezu weiß,
        // sodass das Feld mit dem Hintergrund verschmilzt. Mit explizitem
        // error-/focusedError-Border bleibt der Rahmen im Fehlerzustand immer rot.
        errorBorder: fieldBorder(colorScheme.error),
        focusedErrorBorder: fieldBorder(colorScheme.error, width: 2),
      ),
    );
  }

  List<ExtendedColor> get extendedColors => [];
}
