import 'dart:convert';
import 'dart:io';

import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/import_aehnlichkeit.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/mandanten_namensindex.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arbeitspaket_testaufbau.dart';
import 'mandanten_testaufbau.dart';

/// Der Aehnlichkeitshinweis ist nur die Einbettung von [MandantErkennung] in
/// die Importvorschau. Geprueft wird darum nicht die Namensrechnung selbst
/// (das tut `mandant_erkennung_test.dart`), sondern dass die Einbettung ihr
/// nichts wegnimmt: welche Zeilen gefragt werden, mit welchem Nachnamen — und
/// vor allem, dass der Vorfilter keinen Treffer verschluckt.
void main() {
  List<MandantVorschlag> zuZeile(
    List<Mandant> bestand, {
    String vorname = '',
    String nachname = '',
    List<String> kennzeichen = const [],
  }) => ImportAehnlichkeit.zuZeile(
    zeile: importZeile(
      vorname: vorname,
      nachname: nachname,
      kennzeichen: kennzeichen,
    ),
    index: MandantenNamensindex(bestand),
  );

  List<Mandant> kandidatenZu(List<Mandant> bestand, String nachname) =>
      MandantenNamensindex(bestand).kandidaten(nachname: nachname);

  group('ImportAehnlichkeit.zuZeile', () {
    test('findet "Schmitt" bei vorhandenem "Schmidt"', () {
      final vorschlaege = zuZeile(
        [mandant(1, 'Schmidt', vorname: 'Karl')],
        vorname: 'Karl',
        nachname: 'Schmitt',
      );

      expect(vorschlaege, hasLength(1));
      expect(vorschlaege.single.mandant.nachname, 'Schmidt');
    });

    // „Dr." gehoert nicht zum Namen. Mitgezaehlt lagen die beiden vier Zeichen
    // auseinander — weit jenseits des einen erlaubten Tippfehlers, und der
    // Anwalt bekaeme die Dublette ohne Hinweis.
    test('findet "Dr. Schmidt" bei vorhandenem "Schmidt"', () {
      final vorschlaege = zuZeile(
        [mandant(1, 'Schmidt', vorname: 'Karl')],
        vorname: 'Karl',
        nachname: 'Dr. Schmidt',
      );

      expect(vorschlaege, hasLength(1));
      expect(vorschlaege.single.mandant.id, 1);
    });

    test('eine Zeile ohne Nachnamen liefert nichts', () {
      final vorschlaege = zuZeile([
        mandant(1, 'Schmidt', vorname: 'Karl'),
      ], vorname: 'Karl');

      expect(vorschlaege, isEmpty);
    });

    test('ein Kennzeichen findet den Mandanten auch bei fremdem Namen', () {
      final vorschlaege = zuZeile(
        [
          mandant(1, 'Schmidt', vorname: 'Karl', kennzeichen: ['HG-E 1427']),
        ],
        nachname: 'Wagner',
        kennzeichen: ['hge1427'],
      );

      expect(vorschlaege, hasLength(1));
      expect(vorschlaege.single.mandant.id, 1);
    });

    test('ein fremder Name ohne Kennzeichen liefert nichts', () {
      final vorschlaege = zuZeile([
        mandant(1, 'Schmidt', vorname: 'Karl'),
      ], nachname: 'Wagner');

      expect(vorschlaege, isEmpty);
    });
  });

  // Ein Vorfilter, der etwas aussiebt, was MandantErkennung gefunden haette,
  // ist ein Fehler — und einer, der nirgends auffaellt: die Oberflaeche zeigt
  // dann einfach keinen Hinweis.
  group('MandantenNamensindex laesst nichts durchfallen', () {
    test('ein Tippfehler ueberlebt den Vorfilter', () {
      final kandidaten = kandidatenZu([mandant(1, 'Schmidt')], 'Schmitt');

      expect(kandidaten.map((m) => m.id), contains(1));
    });

    test('ein Tippfehler im ersten Zeichen ueberlebt den Vorfilter', () {
      // „Bauer"/„Auer" waere an einem Eimer ueber die ersten Buchstaben
      // gescheitert: die beiden beginnen verschieden.
      final kandidaten = kandidatenZu([mandant(1, 'Auer')], 'Bauer');

      expect(kandidaten.map((m) => m.id), contains(1));
      expect(
        MandantErkennung.finde(mandanten: kandidaten, nachname: 'Bauer'),
        isNotEmpty,
      );
    });

    test('der abgestreifte Titel ueberlebt den Vorfilter', () {
      final kandidaten = kandidatenZu([
        mandant(1, 'Schmidt'),
      ], ImportAehnlichkeit.ohneTitel('Dr. Schmidt'));

      expect(kandidaten.map((m) => m.id), contains(1));
    });

    test('ein Tippbeginn ueberlebt den Vorfilter', () {
      final kandidaten = kandidatenZu([mandant(1, 'Schmidtberger')], 'Schmidt');

      expect(kandidaten.map((m) => m.id), contains(1));
    });

    test('ein sehr kurzer gespeicherter Nachname ist immer Kandidat', () {
      final kandidaten = kandidatenZu([mandant(1, 'Ho')], 'Hoff');

      expect(kandidaten.map((m) => m.id), contains(1));
    });

    // Der Kennzeichen-Eimer haengt am Grobschluessel, verglichen wird danach
    // ueber gleichesKennzeichen (#147). Das traegt nur, solange der Schluessel
    // eine Obermenge ist: Jedes Paar, das die gemeinsame Falltabelle gleich
    // nennt, muss durch den Vorfilter UND durch MandantErkennung kommen.
    test('jede gleiche Schreibweise eines Kennzeichens ueberlebt den '
        'Vorfilter', () {
      final faelle =
          jsonDecode(File('../docs/kennzeichen_faelle.json').readAsStringSync())
              as Map<String, dynamic>;
      final gleiche = (faelle['vergleiche'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((fall) => fall['gleich'] == true)
          .toList();
      expect(gleiche, isNotEmpty);

      for (final fall in gleiche) {
        final a = fall['a'] as String;
        final b = fall['b'] as String;
        for (final (eingabe, hinterlegt) in [(a, b), (b, a)]) {
          final kandidaten = MandantenNamensindex([
            mandant(1, 'Schmidt', kennzeichen: [hinterlegt]),
          ]).kandidaten(nachname: '', kennzeichen: [eingabe]);

          expect(
            MandantErkennung.finde(
              mandanten: kandidaten,
              kennzeichen: eingabe,
            ).map((v) => v.mandant.id),
            [1],
            reason: '"$eingabe" gegen hinterlegtes "$hinterlegt"',
          );
        }
      }
    });

    test('der Vorfilter laesst ein anders aufgeteiltes Kennzeichen durch, '
        'MandantErkennung sortiert es aus', () {
      final kandidaten = MandantenNamensindex([
        mandant(1, 'Schmidt', kennzeichen: ['HG-E 1427']),
      ]).kandidaten(nachname: '', kennzeichen: ['H-GE 1427']);

      expect(kandidaten.map((m) => m.id), [1]);
      expect(
        MandantErkennung.finde(mandanten: kandidaten, kennzeichen: 'H-GE 1427'),
        isEmpty,
      );
    });
  });

  group('ImportAehnlichkeit.ohneTitel', () {
    test('streift fuehrende Grade ab', () {
      expect(ImportAehnlichkeit.ohneTitel('Dr. Schmidt'), 'Schmidt');
      expect(ImportAehnlichkeit.ohneTitel('Prof. Dr. med. Schmidt'), 'Schmidt');
    });

    test('laesst einen gewoehnlichen Namen in Ruhe', () {
      expect(ImportAehnlichkeit.ohneTitel('Schmidt'), 'Schmidt');
      expect(ImportAehnlichkeit.ohneTitel('von der Heide'), 'von der Heide');
    });

    test('laesst das letzte Wort stehen, auch wenn es ein Grad ist', () {
      expect(ImportAehnlichkeit.ohneTitel('Dr.'), 'Dr.');
    });
  });

  group('ImportAehnlichkeit.zuVorschau', () {
    test('bietet nur Zeilen der Art neu an', () {
      final bestand = [mandant(1, 'Schmidt', vorname: 'Karl')];
      final zeilen = [importZeile(vorname: 'Karl', nachname: 'Schmitt')];

      final neu = vorschau(zeilen);
      final ergaenzt = vorschau(zeilen, art: ImportArt.ergaenzt);

      expect(
        ImportAehnlichkeit.zuVorschau(
          bericht: neu.bericht,
          datei: neu.datei,
          mandanten: bestand,
        ).keys,
        [0],
      );
      expect(
        ImportAehnlichkeit.zuVorschau(
          bericht: ergaenzt.bericht,
          datei: ergaenzt.datei,
          mandanten: bestand,
        ),
        isEmpty,
      );
    });

    test('gibt das Ergebnis je Zeilennummer zurueck', () {
      final bestand = [
        mandant(1, 'Schmidt', vorname: 'Karl'),
        mandant(2, 'Wagner', vorname: 'Anna'),
      ];
      final daten = vorschau([
        importZeile(vorname: 'Karl', nachname: 'Schmitt'),
        importZeile(vorname: 'Bernd', nachname: 'Unbekanntdorf'),
        importZeile(vorname: 'Anna', nachname: 'Wagner'),
      ]);

      final ergebnis = ImportAehnlichkeit.zuVorschau(
        bericht: daten.bericht,
        datei: daten.datei,
        mandanten: bestand,
      );

      expect(ergebnis.keys.toSet(), {0, 2});
      expect(ergebnis[0]!.single.mandant.id, 1);
      expect(ergebnis[2]!.single.mandant.id, 2);
    });

    test('ohne Register gibt es nichts vorzuschlagen', () {
      final daten = vorschau([
        importZeile(vorname: 'Karl', nachname: 'Schmitt'),
      ]);

      expect(
        ImportAehnlichkeit.zuVorschau(
          bericht: daten.bericht,
          datei: daten.datei,
          mandanten: const [],
        ),
        isEmpty,
      );
    });
  });
}
