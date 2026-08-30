import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// App-eigene Platzhalter (#35 Teil 1) haben keinen klickbaren Chip: Ein Klick
/// darf kein Eingabefeld erzeugen, das sich von Hand nie füllen lässt.
void main() {
  Future<List<String>> zeigeUndKlickeAlle(
    WidgetTester tester,
    List<String> placeholders,
  ) async {
    final uebernommen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatzhalterChips(
            placeholders: placeholders,
            onPlaceholderSelected: uebernommen.add,
          ),
        ),
      ),
    );
    for (final placeholder in placeholders) {
      await tester.tap(find.text('{{$placeholder}}'));
    }
    return uebernommen;
  }

  testWidgets('ein Klick auf {{Schadensaufstellung}} übernimmt nichts', (
    tester,
  ) async {
    final uebernommen = await zeigeUndKlickeAlle(tester, [
      'Kennzeichen',
      'Schadensaufstellung',
      'RvgBrutto',
    ]);

    expect(uebernommen, ['Kennzeichen']);
  });

  testWidgets('der app-eigene Chip erklärt sich im Tooltip', (tester) async {
    await zeigeUndKlickeAlle(tester, ['Schadensaufstellung']);

    expect(
      find.byTooltip(
        'Füllt die App beim Erzeugen selbst — kein Eingabefeld nötig.',
      ),
      findsOneWidget,
    );
  });
}
