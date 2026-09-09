import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
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

    test('filtert auf einen einzelnen Jahrgang', () {
      final gefiltert = const RegisterFilter.imJahr(2019).anwenden([
        vorgangsZeile(jahr: '2026', zeichen: 'neu'),
        historieZeile(jahr: '2019', zeichen: 'alt'),
      ]);

      expect(gefiltert.single.zeichen, 'alt');
    });

    /// Die häufigste Frage am Register ist „die letzten Jahre" und nicht
    /// „genau 2021" — die Spanne schließt beide Grenzen ein.
    test('filtert auf eine Jahrgangsspanne, Grenzen eingeschlossen', () {
      final alle = [
        historieZeile(jahr: '2019', zeichen: 'a'),
        historieZeile(jahr: '2020', zeichen: 'b'),
        historieZeile(jahr: '2021', zeichen: 'c'),
        vorgangsZeile(jahr: '2026', zeichen: 'd'),
      ];

      expect(
        const RegisterFilter(
          vonJahr: 2020,
          bisJahr: 2021,
        ).anwenden(alle).map((z) => z.zeichen),
        ['b', 'c'],
      );
    });

    test('eine offene Grenze lässt die Spanne nach dieser Seite offen', () {
      final alle = [
        historieZeile(jahr: '2019', zeichen: 'a'),
        vorgangsZeile(jahr: '2026', zeichen: 'd'),
      ];

      expect(
        const RegisterFilter(vonJahr: 2020).anwenden(alle).single.zeichen,
        'd',
      );
      expect(
        const RegisterFilter(bisJahr: 2020).anwenden(alle).single.zeichen,
        'a',
      );
    });

    /// Eine Zeile ohne lesbare Jahreszahl lässt sich nicht einordnen. Sie
    /// stillschweigend durchzulassen hieße, eine Auswahl zu zeigen, die nicht
    /// gilt — ohne Spanne bleibt sie sichtbar.
    test('eine Zeile ohne Jahreszahl fällt aus der Spanne heraus', () {
      final ohneJahr = [vorgangsZeile(jahr: '', zeichen: 'x')];

      expect(const RegisterFilter(vonJahr: 2020).anwenden(ohneJahr), isEmpty);
      expect(RegisterFilter.alle.anwenden(ohneJahr), hasLength(1));
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

    /// Nach der Übernahme besteht das Register zum größten Teil aus Historie.
    /// Wer die laufende Arbeit sehen will, sucht sie sonst zwischen tausenden
    /// Altzeilen.
    test('filtert nach Herkunft — in beide Richtungen', () {
      final alle = [
        vorgangsZeile(zeichen: 'app'),
        historieZeile(zeichen: 'alt'),
      ];

      expect(
        const RegisterFilter(
          quelle: RegisterQuellen.vorgang,
        ).anwenden(alle).single.zeichen,
        'app',
      );
      expect(
        const RegisterFilter(
          quelle: RegisterQuellen.historie,
        ).anwenden(alle).single.zeichen,
        'alt',
      );
      expect(RegisterFilter.alle.anwenden(alle), hasLength(2));
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

  group('jahre', () {
    test('listet die vorkommenden Jahrgänge als Zahl, neueste zuerst', () {
      final jahre = RegisterFilter.jahre([
        vorgangsZeile(jahr: '2025'),
        vorgangsZeile(jahr: '2026'),
        historieZeile(jahr: '2025'),
      ]);

      expect(jahre, [2026, 2025]);
    });

    test('ein leeres Jahr taucht in der Auswahl nicht auf', () {
      expect(RegisterFilter.jahre([vorgangsZeile(jahr: '')]), isEmpty);
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
      const filter = RegisterFilter(
        abgeschlossen: true,
        vonJahr: 2026,
        bisJahr: 2026,
      );

      final geaendert = filter.mit(jahrLoeschen: true);

      expect(geaendert.abgeschlossen, isTrue);
      expect(geaendert.vonJahr, isNull);
      expect(geaendert.bisJahr, isNull);
      expect(geaendert.istLeer, isFalse);
    });

    /// Sonst bekäme der Anwalt eine leere Tabelle und müsste selbst darauf
    /// kommen, dass er das zweite Feld auch noch anfassen muss.
    test('„von" über „bis" zieht die andere Grenze mit', () {
      const spanne = RegisterFilter(vonJahr: 2019, bisJahr: 2021);

      final nachOben = spanne.mit(vonJahr: 2024);
      expect((nachOben.vonJahr, nachOben.bisJahr), (2024, 2024));

      final nachUnten = spanne.mit(bisJahr: 2018);
      expect((nachUnten.vonJahr, nachUnten.bisJahr), (2018, 2018));
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
