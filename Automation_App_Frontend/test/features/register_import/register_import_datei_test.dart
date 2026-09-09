import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Die Langform ist das, was der Dienst verlangt, und das, was toJson
  // schreibt. Sie muss sich lesen lassen, sonst wäre ein zweiter Lauf über eine
  // von der App erzeugte Datei nicht möglich.
  test('liest die Langform mit mehreren Jahrgängen', () {
    final datei = RegisterImportDatei.fromJson({
      'version': 1,
      'jahrgaenge': [
        {
          'jahrgang': 2019,
          'zeilen': [
            {
              'laufendeNummer': 10,
              'nummerZusatz': '-I',
              'spalte1': '10',
              'aktenzeichen': '10/19-I',
              'abteilung': 'C02',
              'abteilungRoh': 'C 02',
              'mandant': 'Bernd Mustermann',
              'gegner': 'Beate Mustermann',
              'sachbestand': 'Ehescheidung',
              'rechtsgebiet': 'Familienrecht',
              'freitext': '10/19-I C 02 Bernd Mustermann ./. Beate Mustermann',
              'sicherheit': 'niedrig',
              'hinweise': ['Nummer trägt den Zusatz -I'],
            },
          ],
        },
        {'jahrgang': 2020, 'zeilen': <Map<String, dynamic>>[]},
      ],
    });

    expect(datei.version, 1);
    expect(datei.jahrgaenge.map((j) => j.jahrgang), [2019, 2020]);
    final zeile = datei.jahrgaenge.first.zeilen.single;
    expect(zeile.laufendeNummer, 10);
    expect(zeile.nummerZusatz, '-I');
    expect(zeile.abteilungRoh, 'C 02');
    expect(zeile.hinweise, ['Nummer trägt den Zusatz -I']);
    expect(zeile.bearbeitet, isFalse);
  });

  // Wer einen einzelnen Jahrgang liefert, schreibt ihn erfahrungsgemäß flach
  // hin. Beide Formen zu lesen kostet zehn Zeilen und erspart genau die
  // Rückfrage, die sonst jedes Mal käme.
  test('liest die Kurzform mit jahrgang und zeilen auf oberster Ebene', () {
    final datei = RegisterImportDatei.fromJson({
      'version': 1,
      'jahrgang': 2022,
      'zeilen': [
        {
          'laufendeNummer': 6,
          'aktenzeichen': '06/22',
          'abteilung': 'C05/3',
          'sachart': 'Strafsache',
          'mandant': 'Stefan Mustermann',
          'sachbestand': 'Unfallflucht',
          'rechtsgebiet': 'Verkehrsstrafrecht',
          'sicherheit': 'mittel',
        },
      ],
    });

    expect(datei.jahrgaenge.single.jahrgang, 2022);
    expect(datei.jahrgaenge.single.zeilen.single.sachart, 'Strafsache');
    expect(datei.zeilenGesamt, 1);
  });

  test('eine fehlende Fassung gilt als Fassung 1', () {
    final datei = RegisterImportDatei.fromJson({
      'jahrgang': 2018,
      'zeilen': [],
    });

    expect(datei.version, RegisterImportDatei.aktuelleVersion);
    expect(datei.jahrgaenge.single.zeilen, isEmpty);
  });

  test('ohne jahrgaenge und ohne jahrgang bleibt die Datei leer', () {
    final datei = RegisterImportDatei.fromJson({'version': 1});

    expect(datei.jahrgaenge, isEmpty);
    expect(datei.zeilenGesamt, 0);
  });

  // Geschrieben wird immer die Langform: Eine Datei in zwei Schreibweisen sind
  // für den Dienst zwei Fälle, und der zweite fällt erst auf, wenn er falsch
  // ist.
  test('toJson schreibt die Langform, auch nach der Kurzform', () {
    final datei = RegisterImportDatei.fromJson({
      'version': 1,
      'jahrgang': 2022,
      'zeilen': [
        {'laufendeNummer': 1, 'aktenzeichen': '01/22', 'sicherheit': 'hoch'},
      ],
    });

    final json = datei.toJson();

    expect(json.keys, containsAll(<String>['version', 'jahrgaenge']));
    expect(json.containsKey('zeilen'), isFalse);
    final jahrgaenge = json['jahrgaenge'] as List;
    final zeilen =
        (jahrgaenge.single as Map<String, dynamic>)['zeilen'] as List;
    expect((zeilen.single as Map<String, dynamic>)['aktenzeichen'], '01/22');
  });

  // `bearbeitet` gilt dem laufenden Vorgang, nicht dem Bestand — es stünde
  // sonst im Vertrag, ohne dass das Backend etwas damit anfinge.
  test('bearbeitet geht nicht über die Leitung', () {
    final datei = RegisterImportDatei.fromJson({
      'jahrgang': 2022,
      'zeilen': [
        {'laufendeNummer': 1},
      ],
    });
    final geaendert = datei.mitJahrgang(
      datei.jahrgaenge.single.mitZeilen([
        datei.jahrgaenge.single.zeilen.single.copyWith(bearbeitet: true),
      ]),
    );

    final zeilen =
        ((geaendert.toJson()['jahrgaenge'] as List).single
                as Map<String, dynamic>)['zeilen']
            as List;

    expect(geaendert.jahrgaenge.single.zeilen.single.bearbeitet, isTrue);
    expect(
      (zeilen.single as Map<String, dynamic>).containsKey('bearbeitet'),
      isFalse,
    );
  });

  test('nurJahrgang schneidet die Datei auf einen Jahrgang zu', () {
    final datei = RegisterImportDatei.fromJson({
      'jahrgaenge': [
        {
          'jahrgang': 2021,
          'zeilen': [
            {'laufendeNummer': 1},
          ],
        },
        {
          'jahrgang': 2022,
          'zeilen': [
            {'laufendeNummer': 1},
            {'laufendeNummer': 2},
          ],
        },
      ],
    });

    final nur2022 = datei.nurJahrgang(2022);

    expect(nur2022.jahrgaenge.single.jahrgang, 2022);
    expect(nur2022.zeilenGesamt, 2);
  });
}
