import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_testaufbau.dart';

/// Eine maschinell erzeugte Datei enthält Fehler. Ohne einen Weg, eine einzelne
/// Zeile richtigzustellen, bliebe nur die Wahl zwischen „Fehler mitnehmen" und
/// „viertausend richtige Zeilen liegen lassen".
void main() {
  late ImportTestaufbau aufbau;

  setUp(() => aufbau = ImportTestaufbau(inhalt: datei(mandanten: 3)));
  tearDown(() => aufbau.close());

  Future<void> geoeffnet() => aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

  ImportMandantEintrag berichtigt() => const ImportMandantEintrag(
    vorname: 'Markus',
    nachname: 'Schmidt 1',
    ort: 'Frankfurt',
    aktenOrdnernamen: ['VUnfallursache Schmidt 1'],
  );

  test('eine berichtigte Zeile geht berichtigt über die Leitung', () async {
    await geoeffnet();

    await aufbau.cubit.eintragErsetzen(1, berichtigt());

    final geschickt = aufbau.importieren.gesendet.last;
    expect(geschickt.mandanten, hasLength(3));
    expect(geschickt.mandanten[1].vorname, 'Markus');
    expect(geschickt.mandanten[1].ort, 'Frankfurt');
    expect(geschickt.mandanten[0].vorname, 'Mark', reason: 'nur diese Zeile');
  });

  // Die Prüfung macht der Dienst, auch nach einer Änderung. Lokal nachzurechnen
  // wäre eine zweite Auslegung derselben Regeln.
  test('nach dem Bearbeiten wird erneut geprüft, nicht geschrieben', () async {
    await geoeffnet();
    expect(aufbau.importieren.aufrufe, [false]);

    await aufbau.cubit.eintragErsetzen(1, berichtigt());

    expect(aufbau.importieren.aufrufe, [false, false]);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  test('die bearbeitete Zeile ist als solche vermerkt', () async {
    await geoeffnet();
    await aufbau.cubit.eintragErsetzen(1, berichtigt());

    final stand = aufbau.cubit.state;
    expect(stand.eintragAus(1)?.bearbeitet, isTrue);
    expect(stand.eintragAus(0)?.bearbeitet, isFalse);
    expect(stand.bearbeitetAnzahl, 1);
  });

  // Herkunft und Selbsteinschätzung beschreiben den Fund, nicht den Mandanten:
  // wer sie beim Berichtigen verlöre, behielte die Angaben ohne die Auskunft,
  // woher sie stammen.
  test('Quelle und Sicherheit überleben das Bearbeiten', () async {
    await geoeffnet();
    final vorher = aufbau.cubit.state.eintragAus(1)!;

    await aufbau.cubit.eintragErsetzen(
      1,
      ImportMandantEintrag(
        vorname: 'Markus',
        nachname: 'Schmidt 1',
        quelle: vorher.quelle,
        sicherheit: vorher.sicherheit,
      ),
    );

    final nachher = aufbau.cubit.state.eintragAus(1)!;
    expect(nachher.quelle, 'Schmidt 1/Schreiben.docx');
    expect(nachher.sicherheit, 'mittel');
  });

  test('eine weggelassene Zeile verschwindet aus der Datei', () async {
    await geoeffnet();

    await aufbau.cubit.eintragVerwerfen(1);

    final geschickt = aufbau.importieren.gesendet.last;
    expect(
      [for (final m in geschickt.mandanten) m.nachname],
      ['Schmidt 0', 'Schmidt 2'],
    );
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  test('eine Zeilennummer außerhalb der Datei tut nichts', () async {
    await geoeffnet();

    await aufbau.cubit.eintragVerwerfen(7);
    await aufbau.cubit.eintragErsetzen(-1, berichtigt());

    expect(aufbau.importieren.aufrufe, [false]);
    expect(aufbau.cubit.state.datei?.mandanten, hasLength(3));
  });

  test('nach dem Übernehmen ist die Datei unveränderlich', () async {
    await geoeffnet();
    await aufbau.cubit.uebernehmen();

    await aufbau.cubit.eintragErsetzen(1, berichtigt());
    await aufbau.cubit.eintragVerwerfen(1);

    expect(aufbau.importieren.aufrufe, [false, true]);
    expect(aufbau.cubit.state.datei?.mandanten[1].vorname, 'Mark');
  });

  // Schlägt die erneute Prüfung fehl, darf der Zustand nicht halb umgestellt
  // sein: sonst zeigte die Liste Zeilennummern eines Berichts, der nicht mehr
  // zur Datei gehört, und der nächste Klick träfe die falsche Zeile.
  test('eine gescheiterte Prüfung lässt Datei und Bericht stehen', () async {
    await geoeffnet();
    aufbau.importieren.fehler = 'Der Dienst antwortet nicht.';

    await aufbau.cubit.eintragVerwerfen(1);

    final stand = aufbau.cubit.state;
    expect(stand.fehler, 'Der Dienst antwortet nicht.');
    expect(stand.datei?.mandanten, hasLength(3));
    expect(stand.laufend, isFalse);
  });
}
