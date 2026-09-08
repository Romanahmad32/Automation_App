import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Prüft die Ansicht des Registers (§6.2). Seit die Zeilen aus dem Backend
/// kommen und auch die übernommene Historie enthalten, trägt der Filter die
/// Bedienbarkeit der Seite — bei tausenden Zeilen ist „alles zeigen" keine
/// Ansicht mehr.
///
/// **Sortiert wird hier nicht mehr.** Die Reihenfolge stellt
/// `RegisterZeilenBau.Aus` im Backend her, zusammen mit den Zeilen; sie ein
/// zweites Mal zu formulieren, hieße sie zweimal pflegen zu müssen.
void main() {
  group('anwenden', () {
    test('lässt ohne Auswahl alle Zeilen stehen', () {
      final alle = [vorgangsZeile(), historieZeile()];

      expect(RegisterFilter.alle.anwenden(alle), hasLength(2));
    });

    test('behält die Reihenfolge des Backends', () {
      final alle = [
        historieZeile(zeichen: 'a'),
        vorgangsZeile(zeichen: 'b'),
        historieZeile(zeichen: 'c'),
      ];

      expect(RegisterFilter.alle.anwenden(alle).map((z) => z.zeichen), [
        'a',
        'b',
        'c',
      ]);
    });

    test('filtert nach Jahrgang', () {
      final gefiltert = const RegisterFilter(jahr: '2019').anwenden([
        vorgangsZeile(jahr: '2026', zeichen: 'neu'),
        historieZeile(jahr: '2019', zeichen: 'alt'),
      ]);

      expect(gefiltert.single.zeichen, 'alt');
    });

    /// Historie ist per Definition abgeschlossen — sie darf unter „laufend"
    /// nicht auftauchen und unter „abgeschlossen" nicht fehlen.
    test('zählt Historie zu den abgeschlossenen Zeilen', () {
      final alle = [
        vorgangsZeile(zeichen: 'laufend', abgeschlossen: false),
        vorgangsZeile(zeichen: 'fertig'),
        historieZeile(zeichen: 'alt'),
      ];

      expect(
        const RegisterFilter(
          abgeschlossen: true,
        ).anwenden(alle).map((z) => z.zeichen),
        ['fertig', 'alt'],
      );
      expect(
        const RegisterFilter(
          abgeschlossen: false,
        ).anwenden(alle).map((z) => z.zeichen),
        ['laufend'],
      );
    });

    // Der Filter trägt den Katalognamen, der Altbestand ist kleingeschrieben
    // gespeichert — beide müssen sich treffen (RechtsgebietWert.gleich).
    test('filtert nach Rechtsgebiet — auch über den kleingeschriebenen '
        'Altbestand', () {
      final gefiltert = const RegisterFilter(rechtsgebiet: 'Verkehrsstrafrecht')
          .anwenden([
            vorgangsZeile(zeichen: 'a'),
            vorgangsZeile(zeichen: 'b', rechtsgebiet: 'verkehrsstrafrecht'),
          ]);

      expect(gefiltert.single.zeichen, 'b');
    });
  });

  group('jahrgaenge', () {
    test('listet die vorkommenden Jahrgänge, neueste zuerst', () {
      final jahre = RegisterFilter.jahrgaenge([
        vorgangsZeile(jahr: '2025'),
        vorgangsZeile(jahr: '2026'),
        historieZeile(jahr: '2025'),
      ]);

      expect(jahre, ['2026', '2025']);
    });

    test('ein leeres Jahr taucht nicht als Chip auf', () {
      expect(RegisterFilter.jahrgaenge([vorgangsZeile(jahr: '')]), isEmpty);
    });
  });

  group('rechtsgebiete', () {
    /// Die Auswahl der Filterleiste: der Katalog (§7.1) vollständig und in
    /// seiner Reihenfolge — dahinter, was nur im Bestand vorkommt (etwa
    /// Vertragsrecht ohne Katalogeintrag). Ohne die Bestandswerte wäre der
    /// alte Fehler zurück: Zeilen, nach denen niemand filtern kann.
    test('vereint Katalog und Bestand, ohne zu doppeln', () {
      final werte = RegisterFilter.rechtsgebiete(
        [
          vorgangsZeile(rechtsgebiet: 'verkehrsrecht'),
          historieZeile(rechtsgebiet: 'vertragsrecht'),
          vorgangsZeile(rechtsgebiet: ''),
        ],
        katalog: const ['Verkehrsrecht', 'Strafrecht'],
      );

      expect(werte, ['Verkehrsrecht', 'Strafrecht', 'Vertragsrecht']);
    });

    test('ohne Katalog bleiben die Bestandswerte filterbar', () {
      final werte = RegisterFilter.rechtsgebiete([
        vorgangsZeile(rechtsgebiet: 'verkehrsrecht'),
      ]);

      expect(werte, ['Verkehrsrecht']);
    });
  });

  group('mit', () {
    test('setzt ein Feld zurück statt es beizubehalten', () {
      const filter = RegisterFilter(abgeschlossen: true);

      expect(filter.mit(abgeschlossenLoeschen: true).abgeschlossen, isNull);
    });

    test('lässt die übrigen Felder stehen', () {
      const filter = RegisterFilter(abgeschlossen: true, jahr: '2026');

      final geaendert = filter.mit(jahrLoeschen: true);

      expect(geaendert.abgeschlossen, isTrue);
      expect(geaendert.jahr, isNull);
      expect(geaendert.istLeer, isFalse);
    });

    /// `false` ist ein echter Wert und darf nicht wie „nicht angegeben"
    /// wirken — sonst liesse sich „nur laufende Zeilen" nicht einstellen.
    test('nimmt „laufend" als Auswahl an, nicht als fehlende Angabe', () {
      final geaendert = RegisterFilter.alle.mit(abgeschlossen: false);

      expect(geaendert.abgeschlossen, isFalse);
      expect(geaendert.istLeer, isFalse);
    });
  });
}
