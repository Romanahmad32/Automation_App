import 'package:flutter/material.dart';

/// Komponenten-Regeln für die beiden Bausteine, mit denen die App eine
/// **Auswahl** zeigt: [SegmentedButton] und die Chips ([FilterChip],
/// [ChoiceChip], [InputChip]).
///
/// Warum das zentral steht und nicht je Widget: Der ausgewählte Zustand trug
/// bisher allein die Hintergrundfarbe, und Material nimmt dafür
/// `secondaryContainer`. Im Kanzlei-Design sind das `#EFE7E1` auf `#FBF8F4` —
/// gemessen 1,17:1, also rund drei Prozent Helligkeitsunterschied. Das liegt
/// unter jeder Kontrastschwelle und ist für farbfehlsichtige Nutzer gar nicht
/// vorhanden. Wer die Regel je Widget setzt, setzt sie an der nächsten neuen
/// Stelle nicht — deshalb steht sie hier und wird in `theme.dart` einmal in
/// beide Theme-Familien eingehängt.
///
/// **Ausgewählt trägt über Form und Farbe, nie über Farbe allein.**
///
/// *Form* ist das Häkchen. Es ist der Teil, der in jeder Palette und für
/// jedes Auge trägt: seine Farbe ist die Beschriftungsfarbe der Füllung und
/// steht damit immer im vollen Kontrast zu ihr. Material zeigt es von sich
/// aus; die Aufgabe ist allein, es nicht abzuschalten — darüber wacht
/// `test/architecture/auswahl_sichtbar_test.dart`.
///
/// *Farbe* ist `primaryContainer`/`onPrimaryContainer` statt
/// `secondaryContainer`. Wie viel das beiträgt, hängt an der Palette und
/// fällt sehr unterschiedlich aus: Im Standard-Design ist `primaryContainer`
/// ein sattes Blau mit nahezu weißer Schrift und allein schon eindeutig; im
/// Kanzlei-Design bleibt die Füllung blass (1,21:1 hell, 1,19:1 dunkel gegen
/// die Kartenfläche), dort trägt das Häkchen. Dass die Kanzlei-Container
/// für eine Auswahlmarkierung generell zu blass sind, ist ein Thema der
/// Palette und wird hier bewusst nicht angefasst.
abstract final class AuswahlThemes {
  /// Der ausgewählte Zustand eines [SegmentedButton].
  ///
  /// Material löst `backgroundColor`, `foregroundColor` und `overlayColor` je
  /// Segment auf — `WidgetState.selected` meint dort also wirklich „dieses
  /// Segment ist gewählt". Für `side` gilt das **nicht**: Rahmen und
  /// Trennlinien werden einmal für die ganze Gruppe gezeichnet, und
  /// `selected` ist dort „irgendein Segment ist gewählt", also immer wahr.
  /// Ein kräftigerer Rand je gewähltem Segment ist damit nicht zu haben —
  /// bei den Chips schon, siehe [chips].
  ///
  /// Die Auffächerung muss jeden Zustand beantworten: Material nimmt je
  /// Eigenschaft **entweder** die aus dem Theme **oder** die eigene Vorgabe,
  /// nie beide. Wer hier nur den gewählten Fall belegt, lässt den
  /// abgeschalteten ohne Farbe zurück.
  static SegmentedButtonThemeData segmentierteSchaltflaeche(
    ColorScheme farben,
  ) {
    // Ohne Auswahl bleibt das Segment ungefüllt, die Karte scheint durch.
    // Abgeschaltet ebenfalls — so hält es auch Material selbst.
    Color? hintergrund(Set<WidgetState> zustand) {
      final gewaehlt =
          zustand.contains(WidgetState.selected) &&
          !zustand.contains(WidgetState.disabled);
      return gewaehlt ? farben.primaryContainer : null;
    }

    Color vordergrund(Set<WidgetState> zustand) {
      if (zustand.contains(WidgetState.disabled)) {
        return farben.onSurface.withValues(alpha: 0.38);
      }
      return zustand.contains(WidgetState.selected)
          ? farben.onPrimaryContainer
          : farben.onSurface;
    }

    // Der Schleier beim Zeigen und Drücken liegt auf der Füllung und muss
    // deshalb dieselbe Beschriftungsfarbe verwenden wie sie.
    Color? schleier(Set<WidgetState> zustand) {
      final basis = zustand.contains(WidgetState.selected)
          ? farben.onPrimaryContainer
          : farben.onSurface;
      if (zustand.contains(WidgetState.pressed) ||
          zustand.contains(WidgetState.focused)) {
        return basis.withValues(alpha: 0.1);
      }
      if (zustand.contains(WidgetState.hovered)) {
        return basis.withValues(alpha: 0.08);
      }
      return null;
    }

    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(hintergrund),
        foregroundColor: WidgetStateProperty.resolveWith(vordergrund),
        overlayColor: WidgetStateProperty.resolveWith(schleier),
      ),
    );
  }

  /// Der ausgewählte Zustand der Chips — Füllung, Beschriftung, Häkchen und
  /// der Rand, den der [SegmentedButton] nicht je Segment zeichnen kann.
  ///
  /// Zwei Eigenheiten von Material, die man beim Lesen sonst sucht:
  ///
  /// - [ChoiceChip] holt seine Füllung aus `secondarySelectedColor` und seine
  ///   gewählte Beschriftung aus `secondaryLabelStyle`, alle anderen Chips aus
  ///   `selectedColor` und `labelStyle`. Beide Paare müssen belegt sein, sonst
  ///   fällt eine Sorte auf die Vorgabe zurück.
  /// - `labelStyle` gilt für **alle** Chips, auch für die ohne Auswahl
  ///   ([Chip], [ActionChip]). Deren Vorgaben widersprechen sich heute
  ///   (`onSurface` beim einen, `onSurfaceVariant` beim anderen); die Regel
  ///   zieht sie auf `onSurface` zusammen. Das ist der lesbarere der beiden
  ///   Werte — die Beschriftung wird dadurch nirgends blasser.
  static ChipThemeData chips(ColorScheme farben, TextTheme schrift) {
    Color beschriftung(Set<WidgetState> zustand) {
      if (zustand.contains(WidgetState.disabled)) {
        return farben.onSurface.withValues(alpha: 0.38);
      }
      return zustand.contains(WidgetState.selected)
          ? farben.onPrimaryContainer
          : farben.onSurface;
    }

    return ChipThemeData(
      selectedColor: farben.primaryContainer,
      secondarySelectedColor: farben.primaryContainer,
      checkmarkColor: farben.onPrimaryContainer,
      labelStyle: schrift.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(beschriftung),
      ),
      secondaryLabelStyle: schrift.labelLarge?.copyWith(
        color: farben.onPrimaryContainer,
      ),
      // Material lässt den gewählten Chip randlos. Hier trägt der Rand die
      // zweite Hälfte der Regel: eine Form, die auch dann noch da ist, wenn
      // die Füllung sich vom Untergrund kaum abhebt.
      side: WidgetStateBorderSide.resolveWith((zustand) {
        if (zustand.contains(WidgetState.disabled)) {
          return BorderSide(color: farben.onSurface.withValues(alpha: 0.12));
        }
        return zustand.contains(WidgetState.selected)
            ? BorderSide(color: farben.primary, width: 1.5)
            : BorderSide(color: farben.outlineVariant);
      }),
    );
  }
}
