import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_loeschen_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// §6.3: Vor dem Löschen eines Vorgangs entscheidet der Anwalt, ob die
/// gespiegelte Registerzeile bleibt oder mitgeht — vorbelegt ist „behalten",
/// die Antwort, die nichts zusätzlich löscht.
void main() {
  final vorgang = Vorgang.ausAnfrage(
    referenz: '01/26 C03_HG-E 1427',
    angefragtAm: DateTime(2026, 1, 1),
  );

  /// Öffnet den Dialog und liefert das noch offene Ergebnis-Future — der
  /// Aufrufer tippt danach im Dialog weiter, bevor er es abwartet.
  Future<Future<bool?>> oeffneDialog(WidgetTester tester) async {
    late Future<bool?> ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ergebnis = showDialog<bool>(
                  context: context,
                  builder: (_) => VorgangLoeschenDialog(vorgang: vorgang),
                );
              },
              child: const Text('öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    return ergebnis;
  }

  testWidgets('das Häkchen „Registerzeile behalten" ist vorbelegt', (
    tester,
  ) async {
    await oeffneDialog(tester);

    final haekchen = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(haekchen.value, isTrue);
  });

  testWidgets('Abbrechen liefert null — nichts wird gelöscht', (tester) async {
    final ergebnis = await oeffneDialog(tester);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(await ergebnis, isNull);
  });

  testWidgets('mit Häkchen liefert „Löschen" true — die Zeile bleibt', (
    tester,
  ) async {
    final ergebnis = await oeffneDialog(tester);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(await ergebnis, isTrue);
  });

  testWidgets('ohne Häkchen liefert „Löschen" false — die Zeile geht mit', (
    tester,
  ) async {
    final ergebnis = await oeffneDialog(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(await ergebnis, isFalse);
  });
}
