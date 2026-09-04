import 'package:automation_app/features/mandanten/presentation/widgets/kennzeichen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Am Mandanten hängen 0..n Kennzeichen, und sie werden später verglichen —
/// gegen die Zentralruf-Antwort, gegen das Feld im Anspruchsschreiben. Deshalb
/// nimmt der Editor den **normalisierten** Wert auf: Stünde `hg-e1427` neben
/// `HG-E 1427` in derselben Liste, wäre derselbe Wagen zweimal hinterlegt, und
/// die Auswahlhilfe böte ihn zweimal an.
void main() {
  /// Die zuletzt gemeldete Liste — der Wert, der beim Speichern am Mandanten
  /// landet. Absichtlich nicht die Chips: Die zeigen nur, was gemeldet wurde.
  late List<String> gemeldet;

  Future<void> zeigeEditor(
    WidgetTester tester, {
    List<String> vorhanden = const [],
  }) async {
    gemeldet = List.of(vorhanden);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KennzeichenEditor(
            initialKennzeichen: vorhanden,
            onChanged: (werte) => gemeldet = werte,
          ),
        ),
      ),
    );
  }

  Future<void> fuegeHinzu(WidgetTester tester, String eingabe) async {
    await tester.enterText(find.byType(TextField), eingabe);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
  }

  testWidgets('nimmt eine Schreibvariante in der Konvention auf', (
    tester,
  ) async {
    await zeigeEditor(tester);

    await fuegeHinzu(tester, 'hg-e 1427');

    expect(gemeldet, ['HG-E 1427']);
    expect(find.widgetWithText(Chip, 'HG-E 1427'), findsOneWidget);
  });

  testWidgets(
    'erkennt dasselbe Kennzeichen in anderer Schreibweise als Dublette',
    (tester) async {
      await zeigeEditor(tester);

      await fuegeHinzu(tester, 'hg-e 1427');
      await fuegeHinzu(tester, 'HG-E 1427');

      expect(
        find.text('Dieses Kennzeichen ist bereits hinterlegt'),
        findsOneWidget,
      );
      expect(gemeldet, ['HG-E 1427']);
      expect(find.widgetWithText(Chip, 'HG-E 1427'), findsOneWidget);
    },
  );

  /// Dieselbe Auskunft wie im Formular: Ein Wert, bei dem offen ist, wo das
  /// Unterscheidungszeichen endet, kommt nicht in die Liste — er hinge dauerhaft
  /// am Mandanten und träfe später die Zuordnung einer Zentralruf-Antwort.
  testWidgets('nimmt ein mehrdeutiges Kennzeichen nicht auf', (tester) async {
    await zeigeEditor(tester);

    await fuegeHinzu(tester, 'hge1427');

    expect(gemeldet, isEmpty);
    expect(
      find.text('Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427'),
      findsOneWidget,
    );
  });

  testWidgets('zeigt die hinterlegten Kennzeichen als Chips', (tester) async {
    await zeigeEditor(tester, vorhanden: const ['HG-E 1427', 'F-AB 12']);

    expect(find.byType(Chip), findsNWidgets(2));
  });
}
