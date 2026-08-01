import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mueller = Mandant(
    id: 1,
    vorname: 'Max',
    nachname: 'Müller',
    kennzeichen: const ['HG-E 1427'],
    erstelltAm: DateTime(2026, 1, 1),
  );
  final muellerin = Mandant(
    id: 2,
    vorname: 'Erika',
    nachname: 'Müller',
    erstelltAm: DateTime(2026, 1, 1),
  );
  final schmidt = Mandant(
    id: 3,
    vorname: 'Anna',
    nachname: 'Schmidt',
    erstelltAm: DateTime(2026, 1, 1),
  );
  final alle = [mueller, muellerin, schmidt];

  test('erkennt den Mandanten am hinterlegten Kennzeichen', () {
    // Schreibweise egal: ohne Bindestrich, klein, andere Leerzeichen.
    final treffer = MandantErkennung.finde(
      mandanten: alle,
      kennzeichen: 'hge 1427',
    );

    expect(treffer.map((v) => v.mandant.id), [1]);
    expect(treffer.single.begruendung, contains('HGE 1427'));
  });

  test('erkennt ähnliche Nachnamen (Tippbeginn und ein Tippfehler)', () {
    // Tippbeginn (Umlaut ausgeschrieben) trifft beide Müllers.
    final beimTippen = MandantErkennung.finde(
      mandanten: alle,
      nachname: 'Muel',
    );
    expect(beimTippen.map((v) => v.mandant.id), [1, 2]);

    // Ein Tippfehler im vollen Namen.
    final tippfehler = MandantErkennung.finde(
      mandanten: alle,
      nachname: 'Schmitd',
    );
    expect(tippfehler.map((v) => v.mandant.id), [3]);
  });

  test('der Vorname verfeinert unter Namensvettern', () {
    final treffer = MandantErkennung.finde(
      mandanten: alle,
      vorname: 'Eri',
      nachname: 'Müller',
    );

    expect(treffer.map((v) => v.mandant.id), [2]);
  });

  test('schlägt bei zu kurzer oder fremder Eingabe nichts vor', () {
    expect(
      MandantErkennung.finde(mandanten: alle, nachname: 'M'),
      isEmpty,
    );
    expect(
      MandantErkennung.finde(mandanten: alle, nachname: 'Wagner'),
      isEmpty,
    );
    expect(
      MandantErkennung.finde(mandanten: alle, kennzeichen: 'F-AB 1'),
      isEmpty,
    );
  });

  test('Kennzeichen-Treffer stehen vor Namens-Treffern, ohne Duplikate', () {
    final treffer = MandantErkennung.finde(
      mandanten: alle,
      nachname: 'Müller',
      kennzeichen: 'HG-E 1427',
    );

    expect(treffer.first.mandant.id, 1);
    expect(treffer.map((v) => v.mandant.id).toSet().length, treffer.length);
  });
}
