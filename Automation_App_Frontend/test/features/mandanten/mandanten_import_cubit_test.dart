import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_testaufbau.dart';
import 'mandanten_testaufbau.dart';

void main() {
  late ImportTestaufbau aufbau;

  setUp(() => aufbau = ImportTestaufbau());
  tearDown(() => aufbau.close());

  // Der Haltepunkt, um den es geht: eine maschinell erzeugte Zuordnung über
  // tausende Ordner darf nicht schon durch das Öffnen der Datei wirksam werden.
  test('das Wählen einer Datei prüft nur und schreibt nicht', () async {
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    expect(aufbau.importieren.aufrufe, [false]);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
    expect(aufbau.cubit.state.bericht?.angewendet, isFalse);
    expect(aufbau.cubit.state.kannUebernehmen, isTrue);
  });

  test('Übernehmen schreibt und merkt sich das Ergebnis', () async {
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');
    await aufbau.cubit.uebernehmen();

    expect(aufbau.importieren.aufrufe, [false, true]);
    expect(aufbau.cubit.state.uebernommen, isTrue);
    expect(aufbau.cubit.state.kannUebernehmen, isFalse);
  });

  test('ein zweites Übernehmen läuft nicht noch einmal', () async {
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');
    await aufbau.cubit.uebernehmen();
    await aufbau.cubit.uebernehmen();

    expect(aufbau.importieren.schreibendeAufrufe, 1);
  });

  test('ohne gelesene Datei schreibt Übernehmen nichts', () async {
    await aufbau.cubit.uebernehmen();

    expect(aufbau.importieren.aufrufe, isEmpty);
  });

  test('eine unlesbare Datei bleibt eine Meldung, kein Bericht', () async {
    aufbau.lesen.fehler = 'Die Datei ist kein gültiges JSON: Zeile 3';

    await aufbau.cubit.dateiWaehlen('C:/tmp/kaputt.json');

    expect(aufbau.cubit.state.fehler, contains('kein gültiges JSON'));
    expect(aufbau.cubit.state.bericht, isNull);
    expect(aufbau.cubit.state.laufend, isFalse);
    expect(aufbau.importieren.aufrufe, isEmpty);
  });

  // Ohne Wirkung ist „Übernehmen" ein Knopf, der nur behauptet, etwas zu tun.
  test('ein Bericht ohne Wirkung lässt sich nicht übernehmen', () async {
    aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [eintrag(0, art: ImportArt.unveraendert)],
        unveraendert: 1,
      ),
    );

    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    expect(aufbau.cubit.state.kannUebernehmen, isFalse);
  });

  test('Verwerfen führt zurück zur Dateiauswahl', () async {
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');
    aufbau.cubit.zuruecksetzen();

    expect(aufbau.cubit.state.bericht, isNull);
    expect(aufbau.cubit.state.datei, isNull);
    expect(aufbau.cubit.state.dateiPfad, isNull);
  });

  test('der Filter wählt aus, ohne den Bericht anzutasten', () async {
    aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [
          eintrag(0),
          eintrag(1, name: 'Saeed Bein', art: ImportArt.abgelehnt),
        ],
        neu: 1,
        abgelehnt: 1,
        ordnerZugeordnet: 1,
      ),
    );
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    // Voreinstellung ist „zu prüfen": nur die abgelehnte Zeile.
    expect(aufbau.cubit.state.sichtbar.single.anzeigename, 'Saeed Bein');

    aufbau.cubit.filtern(const ImportFilter(sicht: ImportSicht.alle));
    expect(aufbau.cubit.state.sichtbar, hasLength(2));
    expect(aufbau.cubit.state.bericht?.eintraege, hasLength(2));
  });

  // Genau die Auskunft, die der Erzeuger nicht hat: Innerhalb einer Sitzung
  // sähe er „Schmidt" und „Schmitt" nebeneinander, über zwei Sitzungen hinweg
  // nur den zweiten. Der Import selbst vergleicht getrimmt und kleingeschrieben
  // — für ihn sind das zwei Menschen.
  group('ähnlicher Name im Register', () {
    /// Eine Datei mit genau einer Zeile, deren Nachname der Test bestimmt.
    MandantenImportDatei zeile(String nachname) => MandantenImportDatei(
      mandanten: [
        ImportMandantEintrag(
          vorname: 'Mark',
          nachname: nachname,
          aktenOrdnernamen: const ['VUnfallursache Mark Schmitt'],
        ),
      ],
    );

    /// Der Dienst rechnet bei jeder Änderung neu: Trägt die Zeile den Namen
    /// aus dem Register, wird aus `neu` ein `ergaenzt`.
    ImportBericht berichtZu(MandantenImportDatei datei) {
      final eintragsname = datei.mandanten.single.nachname;
      final vorhanden = eintragsname == 'Schmidt';
      return bericht(
        eintraege: [
          eintrag(
            0,
            name: 'Mark $eintragsname',
            art: vorhanden ? ImportArt.ergaenzt : ImportArt.neu,
          ),
        ],
        neu: vorhanden ? 0 : 1,
        ergaenzt: vorhanden ? 1 : 0,
        ordnerZugeordnet: 1,
      );
    }

    setUp(() {
      aufbau = ImportTestaufbau(
        inhalt: zeile('Schmitt'),
        mandanten: [mandant(1, 'Schmidt', vorname: 'Mark')],
      );
      aufbau.importieren.berichtFuer = berichtZu;
    });

    test(
      '„Schmitt" bekommt den Hinweis auf den vorhandenen „Schmidt"',
      () async {
        await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

        expect(
          aufbau.cubit.state.aehnlicheZu(0).single.mandant.anzeigename,
          'Mark Schmidt',
        );
      },
    );

    // Ohne das versteckte die Voreinstellung „zu prüfen" genau die Zeile, um
    // derentwillen der Hinweis gebaut wird: sie ist ja weder abgelehnt noch
    // sonst auffällig.
    test('die Zeile steht damit in „zu prüfen"', () async {
      await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

      expect(aufbau.cubit.state.sichtbar.single.zeile, 0);
      expect(aufbau.cubit.state.zaehler[ImportSicht.zuPruefen], 1);
    });

    test(
      'nach der Berichtigung ist der Hinweis weg und die Zeile ergänzt',
      () async {
        await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');
        await aufbau.cubit.eintragErsetzen(
          0,
          zeile('Schmidt').mandanten.single,
        );

        expect(
          aufbau.cubit.state.bericht?.eintraege.single.art,
          ImportArt.ergaenzt,
        );
        expect(aufbau.cubit.state.aehnlicheZu(0), isEmpty);
        expect(aufbau.cubit.state.sichtbar, isEmpty);
      },
    );

    test('ohne Register bleibt es beim Bericht des Dienstes', () async {
      aufbau = ImportTestaufbau(inhalt: zeile('Schmitt'));
      aufbau.importieren.berichtFuer = berichtZu;

      await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

      expect(aufbau.cubit.state.aehnliche, isEmpty);
      expect(aufbau.cubit.state.sichtbar, isEmpty);
    });
  });
}
