import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// App-eigene Platzhalter (#35 Teil 1) haben keinen klickbaren Chip: Ein Klick
/// darf kein Eingabefeld erzeugen, das sich von Hand nie füllen lässt.
///
/// Was hier **nicht** mehr steht: die Erwartungen an die beiden Zählzeilen
/// unter den Chips („n Platzhalter ohne Feld — sie bleiben …", „14 von 18
/// übernommen") und an „Alle übernehmen". Beides ist mit Stufe 2 von #104 in
/// die `VorlagenStandKarte` gewandert, die über **beide** Word-Dateien
/// zusammen rechnet — je Datei gezählt war ein Platzhalter, der in beiden
/// steht, doppelt dabei. Geprüft wird das dort
/// (`vorlagen_stand_karte_test.dart`); der Baustein wurde ersetzt, nicht die
/// Regel gelockert. Der letzte Test unten wacht darüber, dass hier keine neue
/// Zählung entsteht.
void main() {
  Future<List<String>> zeigeUndKlickeAlle(
    WidgetTester tester,
    List<String> placeholders, {
    List<String> vorhandeneNamen = const [],
  }) async {
    final uebernommen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatzhalterChips(
            placeholders: placeholders,
            vorhandeneNamen: vorhandeneNamen,
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

  testWidgets('ein übernommener Chip ist nicht mehr klickbar', (tester) async {
    final uebernommen = await zeigeUndKlickeAlle(
      tester,
      ['Kennzeichen', 'Frist', 'Schadensaufstellung'],
      vorhandeneNamen: ['kennzeichen'],
    );

    expect(uebernommen, ['Frist']);
  });

  testWidgets('ein offener Chip sagt im Tooltip, was er kostet (#36)', (
    tester,
  ) async {
    await zeigeUndKlickeAlle(
      tester,
      ['Kennzeichen', 'Frist', 'Schadensaufstellung'],
      vorhandeneNamen: ['Kennzeichen'],
    );

    expect(
      find.byTooltip(
        'Platzhalter ohne Feld — bleibt beim Erzeugen roh im Dokument '
        'stehen. Anklicken, um ihn zuzuordnen.',
      ),
      findsOne,
    );
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

  testWidgets('unter den Chips wird nicht mehr gezählt', (tester) async {
    // Der Stand steht an einer Stelle. Käme hier wieder eine Zählung dazu,
    // stünden bei zwei verknüpften Dateien zwei Zahlen neben einer dritten,
    // und keine der drei gälte für die Vorlage.
    await zeigeUndKlickeAlle(
      tester,
      ['Kennzeichen', 'Frist', 'Schadensaufstellung'],
      vorhandeneNamen: ['Kennzeichen'],
    );

    expect(find.textContaining('ohne Feld'), findsNothing);
    expect(find.textContaining('übernommen'), findsNothing);
    expect(find.text('Alle übernehmen'), findsNothing);
  });
}
