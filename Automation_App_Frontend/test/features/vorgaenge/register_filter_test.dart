import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft die Ansicht des Registers (§6.2). Seit es **alle** Vorgänge führt und
/// nicht mehr nur die abgeschlossenen, trägt der Filter die Bedienbarkeit der
/// Seite — und die Jahrgangsregel muss dieselbe Antwort geben wie
/// `RegisterZeilenBau.Jahrgang` im Backend, sonst zeigt die App einen anderen
/// Jahrgang an, als in der Register-Datei steht.
void main() {
  Vorgang vorgang({
    String referenz = '01/26 C03_HG-E 1427',
    int? nummer = 1,
    String? jahr = '26',
    VorgangStatus status = VorgangStatus.versendet,
    String rechtsgebiet = RechtsgebietWert.verkehrsrecht,
    DateTime? angefragtAm,
    DateTime? abgeschlossenAm,
  }) => Vorgang(
    referenz: referenz,
    angefragtAm: angefragtAm ?? DateTime(2026, 1, 5),
    status: status,
    rechtsgebiet: rechtsgebiet,
    laufendeNummer: nummer,
    jahr: jahr,
    abteilung: 'C03',
    abgeschlossenAm: abgeschlossenAm,
  );

  group('Jahrgang', () {
    test('macht aus dem zweistelligen Jahr die vierstellige Überschrift', () {
      expect(RegisterFilter.jahrgang(vorgang(jahr: '26')), '2026');
    });

    test('nimmt ein bereits vierstelliges Jahr unverändert', () {
      expect(RegisterFilter.jahrgang(vorgang(jahr: '2024')), '2024');
    });

    test('fällt ohne Jahresfeld auf das Abschlussdatum zurück', () {
      final ohneJahr = vorgang(
        jahr: null,
        nummer: null,
        angefragtAm: DateTime(2025, 12, 30),
        abgeschlossenAm: DateTime(2026, 1, 8),
      );

      expect(RegisterFilter.jahrgang(ohneJahr), '2026');
    });

    test('nimmt ohne Abschluss das Anfragedatum', () {
      final offen = vorgang(
        jahr: null,
        nummer: null,
        status: VorgangStatus.angefragt,
        angefragtAm: DateTime(2024, 3, 7),
      );

      expect(RegisterFilter.jahrgang(offen), '2024');
    });

    test('listet die vorkommenden Jahrgänge, neueste zuerst', () {
      final jahre = RegisterFilter.jahrgaenge([
        vorgang(jahr: '25'),
        vorgang(jahr: '26'),
        vorgang(jahr: '25'),
      ]);

      expect(jahre, ['2026', '2025']);
    });
  });

  group('anwenden', () {
    test('lässt ohne Auswahl alle Vorgänge stehen', () {
      final alle = [
        vorgang(referenz: 'a', status: VorgangStatus.angefragt),
        vorgang(referenz: 'b'),
      ];

      expect(RegisterFilter.alle.anwenden(alle), hasLength(2));
    });

    test('filtert nach Status', () {
      final gefiltert = const RegisterFilter(status: VorgangStatus.versendet)
          .anwenden([
            vorgang(referenz: 'a', status: VorgangStatus.angefragt),
            vorgang(referenz: 'b'),
          ]);

      expect(gefiltert.single.referenz, 'b');
    });

    test('filtert nach Jahrgang', () {
      final gefiltert = const RegisterFilter(jahr: '2025').anwenden([
        vorgang(referenz: 'a', jahr: '25'),
        vorgang(referenz: 'b', jahr: '26'),
      ]);

      expect(gefiltert.single.referenz, 'a');
    });

    // Der Filter trägt den Katalognamen, der Altbestand ist kleingeschrieben
    // gespeichert — beide müssen sich treffen (RechtsgebietWert.gleich).
    test('filtert nach Rechtsgebiet — auch über den kleingeschriebenen '
        'Altbestand', () {
      final gefiltert = const RegisterFilter(rechtsgebiet: 'Verkehrsstrafrecht')
          .anwenden([
            vorgang(referenz: 'a'),
            vorgang(referenz: 'b', rechtsgebiet: 'verkehrsstrafrecht'),
          ]);

      expect(gefiltert.single.referenz, 'b');
    });

    test('sortiert nach Jahrgang und laufender Nummer', () {
      final sortiert = RegisterFilter.alle.anwenden([
        vorgang(referenz: 'c', nummer: 2, jahr: '26'),
        vorgang(referenz: 'a', nummer: 7, jahr: '25'),
        vorgang(referenz: 'b', nummer: 1, jahr: '26'),
      ]);

      expect(sortiert.map((v) => v.referenz), ['a', 'b', 'c']);
    });

    test('hängt Vorgänge ohne laufende Nummer hinten an ihren Jahrgang', () {
      final sortiert = RegisterFilter.alle.anwenden([
        vorgang(referenz: 'offen', nummer: null, jahr: '26'),
        vorgang(referenz: 'neun', nummer: 9, jahr: '26'),
      ]);

      expect(sortiert.map((v) => v.referenz), ['neun', 'offen']);
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
          vorgang(referenz: 'a', rechtsgebiet: 'verkehrsrecht'),
          vorgang(referenz: 'b', rechtsgebiet: 'vertragsrecht'),
          vorgang(referenz: 'c', rechtsgebiet: ''),
        ],
        katalog: const ['Verkehrsrecht', 'Strafrecht'],
      );

      expect(werte, ['Verkehrsrecht', 'Strafrecht', 'Vertragsrecht']);
    });

    test('ohne Katalog bleiben die Bestandswerte filterbar', () {
      final werte = RegisterFilter.rechtsgebiete([
        vorgang(referenz: 'a', rechtsgebiet: 'verkehrsrecht'),
      ]);

      expect(werte, ['Verkehrsrecht']);
    });
  });

  group('mit', () {
    test('setzt ein Feld zurück statt es beizubehalten', () {
      const filter = RegisterFilter(status: VorgangStatus.versendet);

      expect(filter.mit(statusLoeschen: true).status, isNull);
    });

    test('lässt die übrigen Felder stehen', () {
      const filter = RegisterFilter(
        status: VorgangStatus.versendet,
        jahr: '2026',
      );

      final geaendert = filter.mit(jahrLoeschen: true);

      expect(geaendert.status, VorgangStatus.versendet);
      expect(geaendert.jahr, isNull);
      expect(geaendert.istLeer, isFalse);
    });
  });
}
