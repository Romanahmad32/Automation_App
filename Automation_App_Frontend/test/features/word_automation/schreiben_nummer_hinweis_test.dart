import 'package:automation_app/features/word_automation/presentation/widgets/schreiben_nummer_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Leiste, die fragt, ob korrigiert oder neu geschrieben wird (§4.9, #32,
/// #133). Sie ist die einzige Stelle, an der diese Entscheidung fällt — geraten
/// wird sie nirgends, und seit #133 ist sie auch nicht mehr vorbelegt.
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

  testWidgets('nennt beide Nummern, damit die Wahl konkret ist', (
    tester,
  ) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(find.text('Korrektur von Nr. 1'), findsOneWidget);
    expect(find.text('Neues Schreiben · Nr. 2'), findsOneWidget);
  });

  /// §4.9 verlangt, dass gefragt und nicht geraten wird: Vor der Wahl steht
  /// **keines** der beiden Felder an. Das war vor #133 anders — „Korrektur" war
  /// vorbelegt, und wer die Leiste überlas, überschrieb sein abgelegtes
  /// Schreiben.
  testWidgets('ohne Wahl ist nichts vorbelegt', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    final knopf = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(knopf.selected, isEmpty);
    expect(knopf.emptySelectionAllowed, isTrue);
  });

  /// Vor der Wahl stehen beide Folgen da — das ist die Auskunft, auf der der
  /// Anwalt entscheidet.
  testWidgets('sagt je Wahl in einem Satz die Folge', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(
      find.text('Eine Korrektur ersetzt die gespeicherte Fassung.'),
      findsOneWidget,
    );
    expect(
      find.text('Ein neues Schreiben legt eine weitere daneben.'),
      findsOneWidget,
    );
  });

  /// Nach der Wahl bleibt nur noch die Folge stehen, die auch eintritt.
  testWidgets('nach der Wahl steht nur noch deren Folge da', (tester) async {
    await zeige(tester, bisherigeNummer: 1, neuesSchreiben: true);
    expect(
      find.text('Ein neues Schreiben legt eine weitere daneben.'),
      findsOneWidget,
    );
    expect(
      find.text('Eine Korrektur ersetzt die gespeicherte Fassung.'),
      findsNothing,
    );
  });

  testWidgets('nennt Nummer und Dateinamen des gespeicherten Schreibens', (
    tester,
  ) async {
    await zeige(
      tester,
      bisherigeNummer: 2,
      letzterPfad:
          r'C:\Akten\Mustermann\Anspruchsschreiben an Allianz 2 HGn.docx',
    );
    expect(
      find.text(
        'Gespeichert als Nr. 2: Anspruchsschreiben an Allianz 2 HGn.docx',
      ),
      findsOneWidget,
    );
    expect(find.text('Korrektur von Nr. 2'), findsOneWidget);
  });

  /// Ohne bekannten Pfad entfällt die Zeile, statt einen leeren Namen zu
  /// zeigen. Die Nummer steht dann an den beiden Knöpfen.
  testWidgets('ohne Pfad keine Gespeichert-Zeile', (tester) async {
    await zeige(tester, bisherigeNummer: 1);
    expect(find.textContaining('Gespeichert als Nr.'), findsNothing);
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
      find.text('Zu diesem Vorgang ist bereits ein Schreiben gespeichert.'),
      findsOneWidget,
    );
    await zeige(tester, bisherigeNummer: 3);
    expect(
      find.text('Zu diesem Vorgang sind bereits 3 Schreiben gespeichert.'),
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
