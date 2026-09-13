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
    expect(MandantErkennung.finde(mandanten: alle, nachname: 'M'), isEmpty);
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

  group('Kennzeichen wie gleichesKennzeichen (#147)', () {
    Mandant mitKennzeichen(String kennzeichen) => Mandant(
      id: 4,
      vorname: 'Jan',
      nachname: 'Wolf',
      kennzeichen: [kennzeichen],
      erstelltAm: DateTime(2026, 1, 1),
    );

    // §4.2: Ein anders aufgeteiltes Kennzeichen benennt einen anderen Wagen.
    // Bis #147 strich die Erkennung alle Trennzeichen und schlug zu
    // „H-GE 1427" den Mandanten mit „HG-E 1427" vor — mit der Begründung, das
    // Kennzeichen sei bei ihm hinterlegt.
    test('ein anders aufgeteiltes Kennzeichen schlägt nichts vor', () {
      expect(
        MandantErkennung.finde(mandanten: alle, kennzeichen: 'H-GE 1427'),
        isEmpty,
      );
      expect(
        MandantErkennung.finde(
          mandanten: [mitKennzeichen('HG-E 12345')],
          kennzeichen: 'H-GE 12345',
        ),
        isEmpty,
      );
    });

    test('ein mehrdeutiges Kennzeichen trifft seine Lesart', () {
      // „HGE1427" sagt die Aufteilung nicht; die hinterlegte Seite sagt sie.
      final treffer = MandantErkennung.finde(
        mandanten: alle,
        kennzeichen: 'HGE1427',
      );

      expect(treffer.map((v) => v.mandant.id), [1]);
    });

    test('beim Versicherungskennzeichen zählt die Groß-/Kleinschreibung '
        'nicht, die Trennung schon', () {
      final roller = [mitKennzeichen('123 ABC')];

      expect(
        MandantErkennung.finde(
          mandanten: roller,
          kennzeichen: '123 abc',
        ).map((v) => v.mandant.id),
        [4],
      );
      // Entschieden beim Lösen von #147: Bei einem Wert, den die App nicht
      // als Kfz-Kennzeichen liest, zählen Trennzeichen mit — sonst wären auch
      // „HG-E 12345" und „H-GE 12345" gleich (fünf Ziffern, kein Pkw-Schema).
      // Ein ausgebliebener Vorschlag kostet eine Auswahl von Hand, ein
      // falscher womöglich einen Vorgang am falschen Mandanten.
      expect(
        MandantErkennung.finde(mandanten: roller, kennzeichen: '123ABC'),
        isEmpty,
      );
    });
  });
}
