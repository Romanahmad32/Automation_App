import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_testaufbau.dart';

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
}
