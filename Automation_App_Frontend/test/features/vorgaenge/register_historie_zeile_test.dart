import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Rohstand einer historischen Zeile (`RegisterHistorieZeileDto`) ist das,
/// was der Bearbeiten-Dialog zeigt und `PUT /api/RegisterHistorie/{id}`
/// zurückerwartet. Frontend und Backend sind darüber nur über Zeichenketten
/// verbunden — ein Tippfehler im Feldnamen ist zur Laufzeit ein leeres Feld,
/// und „Übernehmen" schriebe es leer in den Bestand.
void main() {
  Map<String, dynamic> roh() => {
    'id': 42,
    'kennung': 'a1b2c3d4',
    'jahr': 2019,
    'laufendeNummer': 10,
    'nummerZusatz': '-I',
    'aktenzeichen': '10/19-I',
    'abteilung': 'C02',
    'sachart': '',
    'mandant': 'Bernd Mustermann',
    'gegner': 'Beate Mustermann',
    'sachbestand': 'Ehescheidung',
    'unfalldatum': '',
    'rechtsgebiet': 'Familienrecht',
    'freitext': '10/19-I C 02 Bernd Mustermann ./. Beate Mustermann',
    'sicherheit': 'niedrig',
    'befunde': ['Nummer trägt den Zusatz „-I".'],
    'hinweise': ['Sachbestand ohne Datum'],
    'mandantId': null,
    'geaendertAm': '2026-09-08T21:56:20Z',
  };

  test('fromJson liest jedes Feld der Antwort', () {
    final zeile = RegisterHistorieZeile.fromJson(roh());

    expect(zeile.id, 42);
    expect(zeile.kennung, 'a1b2c3d4');
    expect(zeile.jahr, 2019);
    expect(zeile.laufendeNummer, 10);
    expect(zeile.nummerZusatz, '-I');
    expect(zeile.aktenzeichen, '10/19-I');
    expect(zeile.abteilung, 'C02');
    expect(zeile.sachart, '');
    expect(zeile.mandant, 'Bernd Mustermann');
    expect(zeile.gegner, 'Beate Mustermann');
    expect(zeile.sachbestand, 'Ehescheidung');
    expect(zeile.unfalldatum, '');
    expect(zeile.rechtsgebiet, 'Familienrecht');
    expect(zeile.freitext, contains('Bernd Mustermann ./. Beate Mustermann'));
    expect(zeile.sicherheit, RegisterSicherheiten.niedrig);
    expect(zeile.befunde, hasLength(1));
    expect(zeile.hinweise, hasLength(1));
    expect(zeile.mandantId, isNull);
    expect(zeile.geaendertAm, isNotNull);
  });

  /// Eine noch nie berichtigte Zeile hat kein `geaendertAm`, und die
  /// Zuordnung zum Mandanten ist ein späterer Schritt — beides darf die
  /// Ansicht nicht mit einer Ausnahme abwerfen.
  test('fromJson verträgt fehlende Felder', () {
    final zeile = RegisterHistorieZeile.fromJson(const {'id': 7});

    expect(zeile.id, 7);
    expect(zeile.freitext, '');
    expect(zeile.befunde, isEmpty);
    expect(zeile.hinweise, isEmpty);
    expect(zeile.geaendertAm, isNull);
    expect(zeile.sicherheitText, 'sicher');
  });

  test('die Selbsteinschätzung steht in denselben Worten wie am Chip', () {
    final zeile = RegisterHistorieZeile.fromJson(roh());

    expect(zeile.sicherheitText, 'sehr unsicher');
  });

  /// Die sieben änderbaren Felder gehen unverändert in den Dialog. Ein Dialog
  /// mit leeren Feldern machte aus „Übernehmen" einen Löschbefehl.
  test('die Vorbelegung übernimmt genau die änderbaren Felder', () {
    final aenderung = RegisterHistorieAenderung.aus(
      RegisterHistorieZeile.fromJson(roh()),
    );

    expect(
      aenderung,
      const RegisterHistorieAenderung(
        abteilung: 'C02',
        mandant: 'Bernd Mustermann',
        gegner: 'Beate Mustermann',
        sachbestand: 'Ehescheidung',
        rechtsgebiet: 'Familienrecht',
      ),
    );
  });

  /// Jahr und laufende Nummer sind der natürliche Schlüssel des Registers —
  /// wären sie änderbar, könnte eine Berichtigung eine zweite Zeile
  /// überschreiben oder eine Lücke aufreißen, die vorher keine war.
  test('Jahr, Nummer und Freitext gehen nicht mit in die Änderung', () {
    final geschrieben = RegisterHistorieAenderung.aus(
      RegisterHistorieZeile.fromJson(roh()),
    ).toJson();

    expect(geschrieben.keys, [
      'abteilung',
      'sachart',
      'mandant',
      'gegner',
      'sachbestand',
      'unfalldatum',
      'rechtsgebiet',
    ]);
  });
}
