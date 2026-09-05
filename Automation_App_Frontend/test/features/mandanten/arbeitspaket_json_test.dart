import 'dart:convert';

import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arbeitspaket_testaufbau.dart';
import 'mandanten_testaufbau.dart';

/// Feldnamen sind hier die ganze Schnittstelle: Die Paketdatei liest ein
/// fremdes Werkzeug, die Historie kommt aus dem Backend. Ein umbenanntes Feld
/// faellt sonst nirgends auf — die Anwendung uebersetzt weiter, alle anderen
/// Tests bleiben gruen, und der Wert ist zur Laufzeit still leer.
///
/// Die erwarteten Schluessel stehen deshalb woertlich im Test und nicht als
/// Ausdruck ueber die Klasse selbst.
void main() {
  group('Arbeitspaket.toJson', () {
    test('traegt genau die Felder des Dateiformats', () {
      final paket = bauePaket(
        [paketOrdner('VUnfallursache Meier, Anna')],
        nummer: 3,
        bekannteMandanten: [
          BekannterMandant.aus(
            mandant(
              1,
              'Schmidt',
              vorname: 'Karl',
              ordner: ['Strafsache Schmidt, Karl'],
              kennzeichen: ['HG-E 1427'],
            ),
          ),
        ],
      );

      final json = paket.toJson();

      expect(json.keys, [
        'version',
        'paket',
        'erstelltAm',
        'stammordner',
        'anleitung',
        'bekannteMandanten',
        'ordner',
      ]);
      expect(json['version'], 1);
      expect(json['paket'], 3);
      expect(json['erstelltAm'], '2026-09-05T10:12:00.000Z');
      expect(json['stammordner'], 'D:/Akten');

      final bekannt = (json['bekannteMandanten'] as List).single as Map;
      expect(bekannt.keys, ['anzeigename', 'aktenOrdnernamen', 'kennzeichen']);
      expect(bekannt['anzeigename'], 'Karl Schmidt');
      expect(bekannt['aktenOrdnernamen'], ['Strafsache Schmidt, Karl']);
      expect(bekannt['kennzeichen'], ['HG-E 1427']);
    });

    test('ein Ordner mit Mandantenvorschlag traegt beide Zusatzfelder', () {
      final paket = bauePaket([
        paketOrdner(
          'VUnfallursache Meier, Anna',
          vorname: 'Meier,',
          nachname: 'Anna',
          bekannterMandant: 'Anna Meier',
          begruendung: 'Nachname gleich',
        ),
      ]);

      final ordner = (paket.toJson()['ordner'] as List).single as Map;

      expect(ordner.keys, [
        'ordnername',
        'aktentyp',
        'nameVorschlagVorname',
        'nameVorschlagNachname',
        'bekannterMandant',
        'begruendung',
      ]);
      expect(ordner['ordnername'], 'VUnfallursache Meier, Anna');
      expect(ordner['aktentyp'], 'verkehrsunfall');
      expect(ordner['nameVorschlagVorname'], 'Meier,');
      expect(ordner['nameVorschlagNachname'], 'Anna');
      expect(ordner['bekannterMandant'], 'Anna Meier');
      expect(ordner['begruendung'], 'Nachname gleich');
    });

    // Ein leeres Feld liest sich wie eine Aussage („kein Mandant"), und das
    // waere eine, die niemand geprueft hat.
    test('ohne Fund fehlen bekannterMandant und begruendung', () {
      final paket = bauePaket([paketOrdner('VUnfallursache Meier, Anna')]);

      final ordner = (paket.toJson()['ordner'] as List).single as Map;

      expect(ordner.keys, [
        'ordnername',
        'aktentyp',
        'nameVorschlagVorname',
        'nameVorschlagNachname',
      ]);
    });

    test('jeder Aktentyp reist unter seinem Namen', () {
      for (final typ in Aktentyp.values) {
        final paket = bauePaket([paketOrdner('Ordner', aktentyp: typ)]);
        final ordner = (paket.toJson()['ordner'] as List).single as Map;
        expect(ordner['aktentyp'], typ.name);
      }
    });

    test('laesst sich als JSON schreiben', () {
      final text = jsonEncode(bauePaket(vieleOrdner(3), nummer: 2).toJson());

      expect(jsonDecode(text), bauePaket(vieleOrdner(3), nummer: 2).toJson());
    });
  });

  group('ImportPaket.fromJson', () {
    test('liest genau die Feldnamen des Vertrags', () {
      final paket = ImportPaket.fromJson(const {
        'nummer': 3,
        'geholtAm': '2026-09-05T10:12:00.000Z',
        'anzahlOrdner': 200,
        'erledigt': 140,
        'eingelesenAm': '2026-09-06T08:00:00.000Z',
        'zeilen': 187,
      });

      expect(paket.nummer, 3);
      expect(paket.geholtAm, DateTime.utc(2026, 9, 5, 10, 12));
      expect(paket.anzahlOrdner, 200);
      expect(paket.erledigt, 140);
      expect(paket.eingelesenAm, DateTime.utc(2026, 9, 6, 8));
      expect(paket.zeilen, 187);
    });

    test('ein offenes Paket hat kein eingelesenAm und keine Zeilen', () {
      final paket = ImportPaket.fromJson(const {
        'nummer': 4,
        'geholtAm': '2026-09-05T10:12:00.000Z',
        'anzahlOrdner': 200,
        'erledigt': 0,
        'eingelesenAm': null,
        'zeilen': null,
      });

      expect(paket.offen, isTrue);
      expect(paket.eingelesenAm, isNull);
      expect(paket.zeilen, isNull);
      expect(paket.offeneOrdner, 200);
    });

    test('eingelesenAm schliesst das Paket', () {
      final paket = ImportPaket.fromJson(const {
        'nummer': 1,
        'geholtAm': '2026-09-05T10:12:00.000Z',
        'anzahlOrdner': 50,
        'erledigt': 50,
        'eingelesenAm': '2026-09-06T08:00:00.000Z',
        'zeilen': 50,
      });

      expect(paket.offen, isFalse);
      expect(paket.offeneOrdner, 0);
    });

    // Der Fortschritt wird beim Lesen berechnet und der Ordnerbestand aendert
    // sich zwischen zwei Abrufen — eine negative Zahl waere in der Anzeige nur
    // verwirrend.
    test('offeneOrdner wird nie negativ', () {
      final paket = ImportPaket.fromJson(const {
        'nummer': 2,
        'geholtAm': '2026-09-05T10:12:00.000Z',
        'anzahlOrdner': 10,
        'erledigt': 12,
      });

      expect(paket.offeneOrdner, 0);
    });
  });
}
