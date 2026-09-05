import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/kanzlei_theme.dart';
import 'package:automation_app/core/theme/presentation/schriftskala.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft, dass die zentrale Schrift-Anhebung aus Issue #57 in **jeder**
/// Theme-Familie und **beiden** Helligkeiten ankommt — und dass die
/// Komponenten, die ihre Schrift aus dem Theme ziehen, sie nicht unterwegs
/// wieder auf eine feste Zahl festnageln.
///
/// Vier Durchläufe statt einem, aus demselben Grund wie in
/// `auswahl_themes_test.dart`: Standard- und Kanzlei-Design bauen ihre
/// `TextTheme` verschieden auf (das eine über `createTextTheme`, das andere
/// über drei Google-Fonts-Familien), laufen aber beide durch
/// `MaterialTheme.theme`. Eine Anhebung, die nur gegen eine Familie geprüft
/// wird, kann in der anderen fehlen, ohne dass es jemandem auffällt — bis der
/// Anwalt umschaltet und die halbe Oberfläche wieder schrumpft.
///
/// Die erwarteten Ausgangswerte sind die Material-3-Vorgaben
/// (`Typography.englishLike2021`). Sie stehen hier als Zahlen und nicht als
/// Ausdruck über dieselbe Basis, aus der der Code rechnet: Sonst prüfte der
/// Test, ob `x + 2 == x + 2` gilt, statt ob die Schrift tatsächlich größer
/// geworden ist.
void main() {
  // Realistische Eingabe wie im Betrieb: `createTextTheme` baut ebenfalls auf
  // `Theme.of(context).textTheme` auf, statt auf einem leeren `TextTheme()`.
  // Seit `Schriftskala.anheben` zuerst mit `Typography.englishLike2021`
  // mischt, macht ein leeres TextTheme den Test nicht mehr blind — es wäre
  // nur eine unrealistische Eingabe.
  final schrift = ThemeData.light().textTheme;

  final familien = <String, ThemeData>{
    'Standard hell': MaterialTheme(schrift).light(),
    'Standard dunkel': MaterialTheme(schrift).dark(),
    'Kanzlei hell': KanzleiMaterialTheme(schrift).light(),
    'Kanzlei dunkel': KanzleiMaterialTheme(schrift).dark(),
  };

  familien.forEach((name, thema) {
    final text = thema.textTheme;

    group(name, () {
      test('jede Rolle der Skala ist um den Zuschlag angehoben', () {
        // Basiswerte aus `Typography.englishLike2021` (Material 3) — alle
        // neun Rollen aus der Tabelle in schriftskala.dart, nicht nur die
        // Enden: Wer bloß große und kleine prüft, merkt nicht, dass eine
        // Rolle in der Mitte beim nächsten Umbau vergessen wurde.
        expect(text.labelSmall?.fontSize, 11 + Schriftskala.anhebung);
        expect(text.bodySmall?.fontSize, 12 + Schriftskala.anhebung);
        expect(text.labelMedium?.fontSize, 12 + Schriftskala.anhebung);
        expect(text.bodyMedium?.fontSize, 14 + Schriftskala.anhebung);
        expect(text.labelLarge?.fontSize, 14 + Schriftskala.anhebung);
        expect(text.titleSmall?.fontSize, 14 + Schriftskala.anhebung);
        expect(text.titleMedium?.fontSize, 16 + Schriftskala.anhebung);
        expect(text.bodyLarge?.fontSize, 16 + Schriftskala.anhebung);
        expect(text.titleLarge?.fontSize, 22 + Schriftskala.anhebung);
      });

      test('der gefüllte Knopf nimmt die Groesse aus der Skala', () {
        final stil = thema.filledButtonTheme.style;
        expect(stil, isNotNull, reason: 'kein zentrales FilledButtonTheme');

        // Bis Issue #57 stand hier ein festes `fontSize: 15`. Es war kleiner
        // als der angehobene `labelLarge` und hätte die Beschriftung jedes
        // Hauptknopfes von der Skala abgekoppelt.
        final knopfschrift = stil!.textStyle?.resolve(<WidgetState>{});
        expect(
          knopfschrift?.fontSize,
          text.labelLarge?.fontSize,
          reason:
              'Der Knopf trägt die Rolle labelLarge — keine eigene Zahl, '
              'sonst wächst er beim nächsten Dreh an Schriftskala.anhebung '
              'nicht mit.',
        );
      });

      test('die Chip-Beschriftung nimmt die Groesse aus der Skala', () {
        // `AuswahlThemes.chips` bekommt das bereits angehobene TextTheme
        // gereicht. Bekäme es das rohe, blieben Filter- und Auswahl-Chips als
        // einzige Bausteine auf der alten Größe stehen.
        expect(thema.chipTheme.labelStyle?.fontSize, text.labelLarge?.fontSize);
      });
    });
  });

  // Seit Issue #57 wählt der Anwalt die Stufe selbst (Reiter „Darstellung").
  // Die Durchläufe oben prüfen die Vorgabe; hier geht es um die beiden
  // anderen Stufen — und darum, dass die Vorgabe genau die mittlere bleibt.
  group('Schriftstufe', () {
    test('der Zuschlag steigt gleichmaessig um die Schrittweite', () {
      expect(Schriftskala.zuschlag(Schriftstufe.normal), 0);
      expect(Schriftskala.zuschlag(Schriftstufe.groesser), 2);
      expect(Schriftskala.zuschlag(Schriftstufe.amGroessten), 4);
    });

    test('"Normal" laesst die Material-3-Vorgaben unangetastet', () {
      // Der Nullpunkt der Skala: Wer die Anhebung nicht will, bekommt genau
      // das, was Material 3 vorsieht — kein Rest von 0,5 px, der beim
      // Zurückstellen hängen bleibt.
      final text = MaterialTheme(
        schrift,
        schriftstufe: Schriftstufe.normal,
      ).light().textTheme;

      expect(text.bodySmall?.fontSize, 12);
      expect(text.bodyMedium?.fontSize, 14);
      expect(text.titleLarge?.fontSize, 22);
    });

    test('"Am groessten" legt zwei Schritte drauf', () {
      final text = MaterialTheme(
        schrift,
        schriftstufe: Schriftstufe.amGroessten,
      ).light().textTheme;

      expect(text.bodySmall?.fontSize, 16);
      expect(text.bodyMedium?.fontSize, 18);
      expect(text.titleLarge?.fontSize, 26);
    });

    test('ohne Angabe gilt die Vorgabestufe', () {
      // Die vier Durchläufe oben bauen ihre Themes ohne Stufe. Ginge die
      // Vorgabe still auf `normal`, wären sie es, die rot würden — nicht
      // diese Zeile. Sie steht trotzdem hier, weil dieselbe Vorgabe auch die
      // gespeicherten Einstellungen und den Bloc-Anfangszustand trägt.
      expect(Schriftstufe.vorgabe, Schriftstufe.groesser);
      expect(
        MaterialTheme(schrift).light().textTheme.bodySmall?.fontSize,
        MaterialTheme(
          schrift,
          schriftstufe: Schriftstufe.vorgabe,
        ).light().textTheme.bodySmall?.fontSize,
      );
    });

    test('die Kanzlei-Familie nimmt die Stufe genauso an', () {
      // `KanzleiMaterialTheme` reicht die Stufe über `super` weiter. Fiele
      // der Parameter dort weg, bliebe ausgerechnet das Standard-Design der
      // App auf der Vorgabe stehen, während das andere folgt.
      final text = KanzleiMaterialTheme(
        schrift,
        schriftstufe: Schriftstufe.amGroessten,
      ).dark().textTheme;

      expect(text.bodyMedium?.fontSize, 18);
    });
  });
}
