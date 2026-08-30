import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// App-eigene Platzhalter (#35 Teil 1) haben keinen klickbaren Chip: Ein Klick
/// darf kein Eingabefeld erzeugen, das sich von Hand nie füllen lässt.
void main() {
  Future<List<String>> zeigeUndKlickeAlle(
    WidgetTester tester,
    List<String> placeholders, {
    List<String> vorhandeneNamen = const [],
    void Function(List<String>)? onAlleUebernehmen,
  }) async {
    final uebernommen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatzhalterChips(
            placeholders: placeholders,
            vorhandeneNamen: vorhandeneNamen,
            onPlaceholderSelected: uebernommen.add,
            onAlleUebernehmen: onAlleUebernehmen,
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

  testWidgets('ein übernommener Chip ist nicht mehr klickbar und die '
      'Zählzeile zählt nur Übernehmbares', (tester) async {
    final uebernommen = await zeigeUndKlickeAlle(
      tester,
      ['Kennzeichen', 'Frist', 'Schadensaufstellung'],
      vorhandeneNamen: ['kennzeichen'],
    );

    expect(uebernommen, ['Frist']);
    // Schadensaufstellung ist app-eigen und zählt nicht mit.
    expect(find.text('1 von 2 übernommen'), findsOneWidget);
  });

  testWidgets('„Alle übernehmen" liefert nur Übernehmbares in '
      'Dokumentreihenfolge', (tester) async {
    List<String>? geliefert;
    await zeigeUndKlickeAlle(
      tester,
      ['Frist', 'Schadensaufstellung', 'Kennzeichen', 'frist'],
      vorhandeneNamen: ['Kennzeichen'],
      onAlleUebernehmen: (platzhalter) => geliefert = platzhalter,
    );

    await tester.tap(find.text('Alle übernehmen'));
    expect(geliefert, ['Frist']);
  });

  testWidgets('nichts mehr zu übernehmen: der Knopf ist stumm', (tester) async {
    var gerufen = false;
    await zeigeUndKlickeAlle(
      tester,
      ['Kennzeichen'],
      vorhandeneNamen: ['Kennzeichen'],
      onAlleUebernehmen: (_) => gerufen = true,
    );

    await tester.tap(find.text('Alle übernehmen'));
    expect(gerufen, isFalse);
    expect(find.text('1 von 1 übernommen'), findsOneWidget);
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
