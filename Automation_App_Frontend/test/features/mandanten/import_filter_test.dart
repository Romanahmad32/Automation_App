import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_testaufbau.dart';

void main() {
  final eintraege = [
    eintrag(0, name: 'Mark Schmidt'),
    eintrag(1, name: 'Saeed Bein', art: ImportArt.ergaenzt),
    eintrag(2, name: 'Max Mustermann', art: ImportArt.unveraendert),
    eintrag(
      3,
      name: 'Eva Klein',
      art: ImportArt.ergaenzt,
      hinweise: ['Ort weicht ab (Register: „Kassel", Datei: „Fulda")'],
    ),
    eintrag(4, name: '', ordner: const [], art: ImportArt.abgelehnt),
  ];

  test('„zu prüfen" zeigt Abgelehntes und alles mit Hinweis', () {
    const filter = ImportFilter();

    expect(
      [for (final e in filter.anwenden(eintraege)) e.zeile],
      [3, 4],
      reason:
          'Eine ergänzte Zeile mit Hinweis ist genauso prüfenswert wie eine '
          'abgelehnte — die Ergänzung ist ja passiert, nur nicht vollständig.',
    );
  });

  test('die Zähler gelten für alle Zeilen, nicht für die gefilterten', () {
    const filter = ImportFilter(sicht: ImportSicht.neu);
    final zaehler = filter.zaehlen(eintraege);

    expect(zaehler[ImportSicht.alle], 5);
    expect(zaehler[ImportSicht.neu], 1);
    expect(zaehler[ImportSicht.ergaenzt], 2);
    expect(zaehler[ImportSicht.unveraendert], 1);
    expect(zaehler[ImportSicht.zuPruefen], 2);
  });

  test('die Suche greift auf Namen und Ordnernamen', () {
    const nachName = ImportFilter(query: 'bein', sicht: ImportSicht.alle);
    expect(nachName.anwenden(eintraege).single.anzeigename, 'Saeed Bein');

    const nachOrdner = ImportFilter(
      query: 'VUnfallursache',
      sicht: ImportSicht.alle,
    );
    expect(nachOrdner.anwenden(eintraege), hasLength(4));
  });

  test('Suche und Ausschnitt greifen zusammen', () {
    const filter = ImportFilter(query: 'Klein', sicht: ImportSicht.ergaenzt);

    expect(filter.anwenden(eintraege).single.zeile, 3);
  });
}
