import 'package:automation_app/features/word_automation/presentation/widgets/schreiben_nummer_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Zeile, die fragt, ob korrigiert oder neu geschrieben wird (§4.9, #32,
/// #133). Sie ist die einzige Stelle, an der diese Entscheidung fällt — geraten
/// wird sie nirgends, und seit #133 ist sie auch nicht mehr vorbelegt.
///
/// Die Erwartungen an [SegmentedButton] und an den Wortlaut „Gespeichert als
/// Nr. …"/„Korrektur von Nr. …" sind hier bewusst durch die neue, kompaktere
/// Gestalt ersetzt (Entscheidung „Variante B" vom 14.09.2026, auf ausdrücklichen
/// Auftrag): Der Anwender fand die frühere Karte mit acht Zeilen zu dominant.
/// Die fachlichen Pflichten aus §4.9 — Frage statt Vorbelegung, unterscheidbare
/// Wirkung, Sperrmeldung — bleiben unverändert und stehen in `schreiben_wahl_test.dart`.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    required int bisherigeNummer,
    bool? neuesSchreiben,
    String? letzterPfad,
    void Function(bool)? onGeaendert,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SchreibenNummerHinweis(
          bisherigeNummer: bisherigeNummer,
          neuesSchreiben: neuesSchreiben,
          letzterDokumentPfad: letzterPfad,
          onGeaendert: onGeaendert ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('zeigt beide Chips zur Wahl', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(
      find.text(SchreibenNummerHinweis.korrekturChipLabel),
      findsOneWidget,
    );
    expect(find.text(SchreibenNummerHinweis.neuChipLabel), findsOneWidget);
  });

  /// §4.9 verlangt, dass gefragt und nicht geraten wird: Vor der Wahl ist
  /// **keiner** der beiden Chips ausgewählt. Das war vor #133 anders —
  /// „Korrektur" war vorbelegt, und wer die Zeile überlas, überschrieb sein
  /// abgelegtes Schreiben.
  testWidgets('ohne Wahl ist kein Chip ausgewählt', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.every((chip) => chip.selected == false), isTrue);
  });

  /// Vor der Wahl nennt die Unterzeile nur, was bereits gespeichert ist — noch
  /// keine Wirkung, weil noch keine Wahl feststeht.
  testWidgets('ohne Wahl nennt die Unterzeile nur die Nummer', (tester) async {
    await zeige(
      tester,
      bisherigeNummer: 1,
      letzterPfad: r'C:\Akten\Mustermann\Brief.docx',
    );
    expect(
      find.text('Zu diesem Vorgang ist Nr. 1 gespeichert.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Korrektur gewählt: Unterzeile nennt den Dateinamen der ersetzten Fassung',
    (tester) async {
      await zeige(
        tester,
        bisherigeNummer: 1,
        neuesSchreiben: false,
        letzterPfad: r'C:\Akten\Mustermann\Brief.docx',
      );
      expect(find.text('Ersetzt „Brief.docx" (Nr. 1).'), findsOneWidget);
    },
  );

  testWidgets(
    'Korrektur gewählt, aber kein Dateiname bekannt: Unterzeile nennt nur die Nummer',
    (tester) async {
      await zeige(tester, bisherigeNummer: 1, neuesSchreiben: false);
      expect(
        find.text('Ersetzt die gespeicherte Fassung (Nr. 1).'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Neues Schreiben gewählt: Unterzeile nennt die künftige Nummer', (
    tester,
  ) async {
    await zeige(tester, bisherigeNummer: 1, neuesSchreiben: true);
    expect(find.text('Wird als Nr. 2 abgelegt.'), findsOneWidget);
  });

  testWidgets('meldet die Auswahl nach oben', (tester) async {
    final gemeldet = <bool>[];
    await zeige(tester, bisherigeNummer: 1, onGeaendert: gemeldet.add);
    await tester.tap(find.text(SchreibenNummerHinweis.neuChipLabel));
    expect(gemeldet, [true]);
  });

  group('dateinameAus', () {
    test('schneidet Windows- und Unix-Verzeichnisse ab', () {
      expect(
        SchreibenNummerHinweis.dateinameAus(r'C:\a\b\Brief.docx'),
        'Brief.docx',
      );
      expect(
        SchreibenNummerHinweis.dateinameAus('/heim/a/Brief.docx'),
        'Brief.docx',
      );
    });

    test('leer bleibt leer', () {
      expect(SchreibenNummerHinweis.dateinameAus(null), '');
      expect(SchreibenNummerHinweis.dateinameAus('   '), '');
    });
  });
}
