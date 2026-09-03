import 'package:automation_app/core/theme/presentation/kanzlei_theme.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft die zentrale Auswahlregel für **jede** Theme-Familie und **beide**
/// Helligkeiten: ausgewählt trägt `primaryContainer`/`onPrimaryContainer`, die
/// Chips zusätzlich einen kräftigeren Rand.
///
/// Vier Durchläufe statt einem, weil genau hier der stille Fehler sitzt: Die
/// Farbrollen sind je Palette anders belegt. Im Standard-Design ist
/// `primaryContainer` ein sattes Blau, im Kanzlei-Design ein blasses Creme —
/// eine Regel, die nur gegen eine der beiden Paletten geprüft wird, sieht in
/// der anderen anders aus, und niemand merkt es, bis der Anwalt umschaltet.
void main() {
  // Eine echte Schrift-Skala statt `TextTheme()`: Die Chip-Beschriftung baut
  // auf `labelLarge` auf, und mit einem leeren TextTheme wäre sie null — der
  // Test liefe grün, ohne je eine Farbe angesehen zu haben.
  final schrift = ThemeData.light().textTheme;

  final familien = <String, ThemeData>{
    'Standard hell': MaterialTheme(schrift).light(),
    'Standard dunkel': MaterialTheme(schrift).dark(),
    'Kanzlei hell': KanzleiMaterialTheme(schrift).light(),
    'Kanzlei dunkel': KanzleiMaterialTheme(schrift).dark(),
  };

  familien.forEach((name, thema) {
    final farben = thema.colorScheme;

    group(name, () {
      test('das gewählte Segment trägt die Primär-Container-Rolle', () {
        final stil = thema.segmentedButtonTheme.style;
        expect(stil, isNotNull, reason: 'kein zentrales SegmentedButtonTheme');

        expect(
          stil!.backgroundColor?.resolve({WidgetState.selected}),
          farben.primaryContainer,
        );
        expect(
          stil.foregroundColor?.resolve({WidgetState.selected}),
          farben.onPrimaryContainer,
        );
      });

      test('das nicht gewählte Segment bleibt ungefüllt und lesbar', () {
        final stil = thema.segmentedButtonTheme.style!;

        // Ohne Füllung scheint die Karte durch — so trennt sich das gewählte
        // Segment von den anderen, statt dass alle drei eine Fläche tragen.
        expect(stil.backgroundColor?.resolve({}), isNull);
        expect(stil.foregroundColor?.resolve({}), farben.onSurface);
      });

      test('das abgeschaltete Segment behält eine Schriftfarbe', () {
        // Material nimmt je Eigenschaft entweder die Theme-Fassung oder die
        // eigene Vorgabe, nie beide: Wer nur den gewählten Fall belegt, lässt
        // die abgeschaltete Schaltfläche ohne Farbe zurück.
        final stil = thema.segmentedButtonTheme.style!;

        expect(
          stil.foregroundColor?.resolve({WidgetState.disabled}),
          isNotNull,
        );
      });

      test('der gewählte Chip trägt Füllung, Beschriftung und Rand', () {
        final chips = thema.chipTheme;

        // Material holt die Füllung je nach Chip-Art aus zwei verschiedenen
        // Feldern — ist nur eines belegt, fällt eine Sorte zurück auf blass.
        expect(chips.selectedColor, farben.primaryContainer);
        expect(chips.secondarySelectedColor, farben.primaryContainer);
        expect(chips.checkmarkColor, farben.onPrimaryContainer);

        expect(
          WidgetStateProperty.resolveAs<Color?>(chips.labelStyle?.color, {
            WidgetState.selected,
          }),
          farben.onPrimaryContainer,
        );
        expect(chips.secondaryLabelStyle?.color, farben.onPrimaryContainer);
      });

      test('der Rand des gewählten Chips ist kräftiger als der offene', () {
        final chips = thema.chipTheme;

        final gewaehlt = WidgetStateProperty.resolveAs<BorderSide?>(
          chips.side,
          {WidgetState.selected},
        );
        final offen = WidgetStateProperty.resolveAs<BorderSide?>(
          chips.side,
          <WidgetState>{},
        );

        expect(gewaehlt?.color, farben.primary);
        expect(gewaehlt!.width, greaterThan(offen!.width));
      });
    });
  });
}
