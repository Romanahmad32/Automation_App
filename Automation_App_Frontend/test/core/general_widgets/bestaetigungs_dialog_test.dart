import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget aufrufer(void Function(bool ergebnis) merken) {
    return MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final ergebnis = await bestaetigen(
              context,
              titel: 'Löschen?',
              text: 'Wirklich löschen?',
              bestaetigung: 'Löschen',
              destruktiv: true,
            );
            merken(ergebnis);
          },
          child: const Text('öffnen'),
        ),
      ),
    );
  }

  testWidgets('liefert true bei Bestätigung', (tester) async {
    bool? ergebnis;
    await tester.pumpWidget(aufrufer((wert) => ergebnis = wert));

    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Löschen?'), findsOneWidget);
    expect(find.text('Wirklich löschen?'), findsOneWidget);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(ergebnis, isTrue);
  });

  testWidgets('liefert false bei Abbrechen', (tester) async {
    bool? ergebnis;
    await tester.pumpWidget(aufrufer((wert) => ergebnis = wert));

    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(ergebnis, isFalse);
  });

  testWidgets('der ablehnende Knopf lässt sich benennen', (tester) async {
    // „Abbrechen" passt nur, solange die Rückfrage vor einer Handlung steht.
    // Beim Verlassen einer Seite mit ungespeicherten Änderungen ist die
    // Ablehnung selbst eine Handlung (#104) — und „Abbrechen" liesse offen,
    // was abgebrochen wird.
    bool? ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              ergebnis = await bestaetigen(
                context,
                titel: 'Änderungen verwerfen?',
                text: 'Beim Verlassen gehen sie verloren.',
                bestaetigung: 'Verwerfen',
                abbruch: 'Weiter bearbeiten',
                destruktiv: true,
              );
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Abbrechen'), findsNothing);

    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();

    expect(ergebnis, isFalse);
  });
}
