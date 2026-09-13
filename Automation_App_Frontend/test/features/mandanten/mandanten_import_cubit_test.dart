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

  // Die Datei kommt von einem Programm, das einen Ordnernamen erfinden kann.
  // Gespeichert wäre er nie wieder auffindbar — und sähe wie eine erledigte
  // Zuordnung aus.
  test('eine Zeile mit unbekanntem Ordner sperrt die Übernahme', () async {
    aufbau = ImportTestaufbau(
      inhalt: const MandantenImportDatei(
        mandanten: [
          ImportMandantEintrag(
            vorname: 'Mark',
            nachname: 'Schmidt',
            aktenOrdnernamen: ['VUnfallursache Erfunden'],
          ),
        ],
      ),
      ordner: const ['VUnfallursache Schmidt'],
    );

    await aufbau.geoeffnet();

    expect(aufbau.cubit.state.befund.unbekannteZeilen, {0});
    expect(aufbau.cubit.state.befund.sperrtUebernahme, isTrue);
    expect(
      aufbau.cubit.state.kannUebernehmen,
      isFalse,
      reason: 'der Bericht bewirkt etwas — aufgehalten wird nur der Ordner',
    );
  });

  // Ohne Scan wäre die Sperre eine Behauptung über Ordner, die niemand kennt:
  // der Import muss auch dort laufen, wo der Stammordner gerade fehlt.
  test('ohne Scan sperrt eine unbekannte Ordnerangabe nicht', () async {
    aufbau = ImportTestaufbau(
      inhalt: const MandantenImportDatei(
        mandanten: [
          ImportMandantEintrag(
            vorname: 'Mark',
            nachname: 'Schmidt',
            aktenOrdnernamen: ['VUnfallursache Erfunden'],
          ),
        ],
      ),
    );

    await aufbau.geoeffnet();

    expect(aufbau.cubit.state.umfeld.ordnernamen, isEmpty);
    expect(aufbau.cubit.state.befund.unbekannteZeilen, isEmpty);
    expect(aufbau.cubit.state.kannUebernehmen, isTrue);
  });

  test('ein Vermerk auf einen unbekannten Ordner sperrt ebenso', () async {
    aufbau = ImportTestaufbau(
      inhalt: const MandantenImportDatei(
        mandanten: [
          ImportMandantEintrag(
            vorname: 'Mark',
            nachname: 'Schmidt',
            aktenOrdnernamen: ['VUnfallursache Schmidt'],
          ),
        ],
        ohneMandantenbezug: ['Buchhaltung 2019'],
      ),
      ordner: const ['VUnfallursache Schmidt'],
    );

    await aufbau.geoeffnet();

    expect(aufbau.cubit.state.befund.unbekannteZeilen, isEmpty);
    expect(aufbau.cubit.state.befund.unbekannteOhneBezug, ['Buchhaltung 2019']);
    expect(aufbau.cubit.state.kannUebernehmen, isFalse);
  });

  // Der Weg aus dem Zuordnungsstapel: eine im Arbeitsspeicher zusammengestellte
  // Datei läuft durch dieselbe Vorschau wie jede Datei von der Platte.
  test('uebernimmDatei fährt die Vorschau ohne Dateiauswahl', () async {
    await aufbau.cubit.uebernimmDatei(
      datei(mandanten: 2),
      herkunft: 'Sichere Treffer aus 380 Ordnern',
    );

    expect(aufbau.lesen.aufrufe, 0, reason: 'nichts von der Platte gelesen');
    expect(aufbau.importieren.aufrufe, [
      false,
    ], reason: 'geprüft, nicht geschrieben');
    expect(aufbau.importieren.gesendet.single.mandanten, hasLength(2));
    expect(aufbau.cubit.state.dateiPfad, 'Sichere Treffer aus 380 Ordnern');
    expect(aufbau.cubit.state.kannUebernehmen, isTrue);
  });

  test('der Akten-Scan läuft einmal, nicht je geprüfter Datei', () async {
    aufbau = ImportTestaufbau(ordner: const ['VUnfallursache Schmidt 0']);

    await aufbau.geoeffnet();
    await aufbau.cubit.eintragVerwerfen(0);
    aufbau.cubit.zuruecksetzen();

    expect(aufbau.scan.aufrufe, 1);
    expect(aufbau.cubit.state.umfeld.ordnernamen, [
      'VUnfallursache Schmidt 0',
    ], reason: '„Andere Datei" wirft die Datei weg, nicht den Scan');
  });

  // Wo der Dienst den Mandanten schon gefunden hat, wäre ein Vorschlag daneben
  // bestenfalls Lärm.
  test('der Ähnlichkeitshinweis gilt nur für neue Zeilen', () async {
    ImportTestaufbau mitArt(ImportArt art) => ImportTestaufbau(
      inhalt: const MandantenImportDatei(
        mandanten: [ImportMandantEintrag(vorname: 'Mark', nachname: 'Schmitt')],
      ),
      antwort: bericht(
        eintraege: [eintrag(0, name: 'Mark Schmitt', art: art)],
        neu: art == ImportArt.neu ? 1 : 0,
        ergaenzt: art == ImportArt.ergaenzt ? 1 : 0,
        ordnerZugeordnet: 1,
      ),
      register: [mandant(7, 'Schmidt', vorname: 'Mark')],
    );

    aufbau = mitArt(ImportArt.neu);
    await aufbau.geoeffnet();
    expect(
      aufbau.cubit.state.befund.aehnliche[0]?.single.mandant.nachname,
      'Schmidt',
    );

    await aufbau.close();
    aufbau = mitArt(ImportArt.ergaenzt);
    await aufbau.geoeffnet();
    expect(aufbau.cubit.state.befund.aehnliche, isEmpty);
  });
}
