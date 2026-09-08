import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_import_testaufbau.dart';

void main() {
  late RegisterImportTestaufbau aufbau;

  setUp(() => aufbau = RegisterImportTestaufbau());
  tearDown(() => aufbau.close());

  // Der Haltepunkt, um den es geht: ein maschinell erzeugter Auszug aus einem
  // neunzigseitigen Register darf nicht schon durch das Öffnen der Datei
  // wirksam werden.
  test('das Wählen einer Datei prüft nur und schreibt nicht', () async {
    await aufbau.geoeffnet();

    expect(aufbau.importieren.aufrufe, [false]);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
    expect(aufbau.cubit.state.bericht?.angewendet, isFalse);
    expect(aufbau.cubit.state.bericht?.jahrgaenge.single.jahrgang, 2022);
    expect(aufbau.cubit.state.kannUebernehmen, isTrue);
  });

  test('die Vorschau nennt die fehlenden Nummern des Jahrgangs', () async {
    aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(zeilen: [zeile(1), zeile(3), zeile(4)]),
    );

    await aufbau.geoeffnet();

    expect(aufbau.cubit.state.bericht?.jahrgaenge.single.luecken, [2]);
  });

  test('eine unlesbare Datei bleibt eine Meldung, kein Bericht', () async {
    aufbau.lesen.fehler = 'Die Datei ist kein gültiges JSON: Zeile 3';

    await aufbau.geoeffnet();

    expect(aufbau.cubit.state.fehler, contains('kein gültiges JSON'));
    expect(aufbau.cubit.state.bericht, isNull);
    expect(aufbau.cubit.state.laufend, isFalse);
    expect(aufbau.importieren.aufrufe, isEmpty);
  });

  // Voreinstellung „nur zu prüfen": Bei zweihundert Zeilen je Jahrgang ist die
  // vollständige Liste keine Prüfung.
  test('der Filter zeigt genau die Zeilen mit zuPruefen', () async {
    aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(
        zeilen: [
          zeile(1),
          zeile(2, sicherheit: 'niedrig'),
          zeile(3, spalte1: '9'),
          zeile(4),
        ],
      ),
    );
    await aufbau.geoeffnet();
    final befund = aufbau.cubit.state.bericht!.jahrgaenge.single;

    expect(aufbau.cubit.state.nurZuPruefen, isTrue);
    expect(befund.sichtbar(nurZuPruefen: true).map((e) => e.laufendeNummer), [
      2,
      3,
    ]);
    expect(befund.zuPruefen, 2);

    aufbau.cubit.filtern(false);

    expect(
      befund
          .sichtbar(nurZuPruefen: aufbau.cubit.state.nurZuPruefen)
          .map((e) => e.laufendeNummer),
      [1, 2, 3, 4],
    );
  });

  test('zeileErsetzen merkt die Zeile als bearbeitet und prüft neu', () async {
    await aufbau.geoeffnet();
    final vorher = aufbau.cubit.state.zeileAus(2022, 2)!;

    await aufbau.cubit.zeileErsetzen(
      2022,
      2,
      vorher.copyWith(rechtsgebiet: 'Familienrecht'),
    );

    final zeilen = aufbau.importieren.gesendet.last.jahrgaenge.single.zeilen;
    expect(zeilen[1].rechtsgebiet, 'Familienrecht');
    expect(zeilen[1].bearbeitet, isTrue);
    expect(zeilen[0].bearbeitet, isFalse);
    expect(aufbau.cubit.state.bearbeitetAnzahl, 1);
    // Die Änderung löst eine neue Prüfung der ganzen Datei aus, keine Schreibung.
    expect(aufbau.importieren.aufrufe, [false, false]);
  });

  // BLOCKIEREND (Review): ein Jahrgang ohne `neu`-Zeilen darf sich weiter
  // berichtigen lassen — nur `kannJahrgangUebernehmen` hängt an `bewirktEtwas`,
  // `kannJahrgangBearbeiten` (und damit zeileErsetzen) nicht.
  test(
    'ein Jahrgang ohne neue Zeilen laesst sich trotzdem berichtigen',
    () async {
      aufbau = RegisterImportTestaufbau(
        berichtVon: (datei) => RegisterImportBericht(
          jahrgaenge: [
            for (final jahr in datei.jahrgaenge)
              JahrgangBefund(
                jahrgang: jahr.jahrgang,
                zeilen: jahr.zeilen.length,
                unveraendert: jahr.zeilen.length,
              ),
          ],
        ),
      );
      await aufbau.geoeffnet();
      final vorher = aufbau.cubit.state.zeileAus(2022, 1)!;

      expect(aufbau.cubit.state.kannJahrgangUebernehmen(2022), isFalse);
      expect(aufbau.cubit.state.kannJahrgangBearbeiten(2022), isTrue);

      await aufbau.cubit.zeileErsetzen(
        2022,
        1,
        vorher.copyWith(rechtsgebiet: 'Familienrecht'),
      );

      final zeilen = aufbau.importieren.gesendet.last.jahrgaenge.single.zeilen;
      expect(zeilen[0].rechtsgebiet, 'Familienrecht');
      expect(zeilen[0].bearbeitet, isTrue);
      // Berichtigen loest eine neue Vorschau aus, kein Schreiben.
      expect(aufbau.importieren.aufrufe, [false, false]);
    },
  );

  test('zeileVerwerfen nimmt genau diese Zeile aus dem Vorgang', () async {
    await aufbau.geoeffnet();

    await aufbau.cubit.zeileVerwerfen(2022, 1);

    final zeilen = aufbau.importieren.gesendet.last.jahrgaenge.single.zeilen;
    expect(zeilen.map((z) => z.laufendeNummer), [2]);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  test('eine Zeilennummer außerhalb des Jahrgangs ändert nichts', () async {
    await aufbau.geoeffnet();

    await aufbau.cubit.zeileVerwerfen(2022, 99);
    await aufbau.cubit.zeileVerwerfen(1999, 1);

    expect(aufbau.importieren.aufrufe, [false]);
  });

  // Ein Jahrgang ist die Menge, die ein Mensch prüfen kann — er soll ihn
  // abschließen können, ohne auf die übrigen zu warten.
  test('uebernehmen(jahrgang) schickt nur diesen Jahrgang', () async {
    aufbau = RegisterImportTestaufbau(
      inhalt: registerDateiMitJahrgaengen({
        2021: [zeile(1, jahrgang: 2021)],
        2022: [zeile(1), zeile(2)],
      }),
    );
    await aufbau.geoeffnet();

    await aufbau.cubit.uebernehmen(jahrgang: 2022);

    expect(aufbau.importieren.aufrufe, [false, true]);
    final geschickt = aufbau.importieren.gesendet.last;
    expect(geschickt.jahrgaenge.map((j) => j.jahrgang), [2022]);
    expect(geschickt.zeilenGesamt, 2);
  });

  test('nach einem Jahrgang bleiben die übrigen Karten stehen', () async {
    aufbau = RegisterImportTestaufbau(
      inhalt: registerDateiMitJahrgaengen({
        2021: [zeile(1, jahrgang: 2021)],
        2022: [zeile(1)],
      }),
    );
    await aufbau.geoeffnet();

    await aufbau.cubit.uebernehmen(jahrgang: 2022);

    final stand = aufbau.cubit.state;
    expect(stand.bericht?.jahrgaenge.map((j) => j.jahrgang), [2021, 2022]);
    expect(stand.istUebernommen(2022), isTrue);
    expect(stand.istUebernommen(2021), isFalse);
    expect(stand.kannJahrgangUebernehmen(2022), isFalse);
    expect(stand.kannJahrgangUebernehmen(2021), isTrue);
    // Erst wenn alle Jahrgänge der Datei geschrieben sind, ist sie angewendet.
    expect(stand.uebernommen, isFalse);

    await aufbau.cubit.uebernehmen(jahrgang: 2021);

    expect(aufbau.cubit.state.uebernommen, isTrue);
  });

  test('derselbe Jahrgang wird kein zweites Mal geschrieben', () async {
    await aufbau.geoeffnet();

    await aufbau.cubit.uebernehmen(jahrgang: 2022);
    await aufbau.cubit.uebernehmen(jahrgang: 2022);

    expect(aufbau.importieren.schreibendeAufrufe, 1);
  });

  test('Alle übernehmen schickt die ganze Datei', () async {
    aufbau = RegisterImportTestaufbau(
      inhalt: registerDateiMitJahrgaengen({
        2021: [zeile(1, jahrgang: 2021)],
        2022: [zeile(1)],
      }),
    );
    await aufbau.geoeffnet();

    await aufbau.cubit.uebernehmen();

    expect(aufbau.importieren.aufrufe, [false, true]);
    expect(aufbau.importieren.gesendet.last.jahrgaenge.length, 2);
    expect(aufbau.cubit.state.uebernommen, isTrue);
    expect(aufbau.cubit.state.kannUebernehmen, isFalse);
  });

  test('ohne gelesene Datei schreibt Übernehmen nichts', () async {
    await aufbau.cubit.uebernehmen();

    expect(aufbau.importieren.aufrufe, isEmpty);
  });

  test('eine geschriebene Zeile lässt sich nicht mehr ändern', () async {
    await aufbau.geoeffnet();
    await aufbau.cubit.uebernehmen(jahrgang: 2022);

    await aufbau.cubit.zeileVerwerfen(2022, 1);

    expect(aufbau.importieren.aufrufe, [false, true]);
  });

  test('Zurücksetzen führt zurück zur Dateiauswahl', () async {
    await aufbau.geoeffnet();
    aufbau.cubit.zuruecksetzen();

    expect(aufbau.cubit.state.bericht, isNull);
    expect(aufbau.cubit.state.datei, isNull);
    expect(aufbau.cubit.state.dateiPfad, isNull);
    expect(aufbau.cubit.state.uebernommeneJahrgaenge, isEmpty);
  });
}
