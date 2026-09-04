import 'package:automation_app/features/word_automation/presentation/widgets/schreiben_nummer_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Leiste, die ab dem zweiten Schreiben eines Vorgangs fragt, ob korrigiert
/// oder neu geschrieben wird (§4.9, #32). Sie ist die einzige Stelle, an der
/// diese Entscheidung fällt — geraten wird sie nirgends.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    required int bisherigeNummer,
    bool neuesSchreiben = false,
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

  testWidgets('nennt beide Nummern, damit die Wahl konkret ist', (
    tester,
  ) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(find.text('Korrektur von Nr. 1'), findsOneWidget);
    expect(find.text('Neues Schreiben · Nr. 2'), findsOneWidget);
  });

  testWidgets('zeigt den Dateinamen des vorigen Schreibens', (tester) async {
    await zeige(
      tester,
      bisherigeNummer: 2,
      letzterPfad:
          r'C:\Arbeit\84-26 C03\Anspruchsschreiben an Allianz 2 HGN.docx',
    );
    expect(
      find.text('Zuletzt: Anspruchsschreiben an Allianz 2 HGN.docx'),
      findsOneWidget,
    );
    expect(find.text('Korrektur von Nr. 2'), findsOneWidget);
  });

  /// Ohne bekannten Pfad entfällt die Zeile, statt „Zuletzt: " leer zu zeigen.
  testWidgets('ohne Pfad keine Zuletzt-Zeile', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(find.textContaining('Zuletzt:'), findsNothing);
  });

  testWidgets('meldet die Auswahl nach oben', (tester) async {
    final gemeldet = <bool>[];
    await zeige(tester, bisherigeNummer: 1, onGeaendert: gemeldet.add);
    await tester.tap(find.text('Neues Schreiben · Nr. 2'));
    expect(gemeldet, [true]);
  });

  /// Der Text unterscheidet Ein- und Mehrzahl — „gibt es bereits 1 Schreiben"
  /// liest sich wie ein Programmfehler.
  testWidgets('Einzahl bei einem, Mehrzahl darüber', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(
      find.text('Zu diesem Vorgang gibt es bereits ein Schreiben.'),
      findsOneWidget,
    );
    await zeige(tester, bisherigeNummer: 3);
    expect(
      find.text('Zu diesem Vorgang gibt es bereits 3 Schreiben.'),
      findsOneWidget,
    );
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
