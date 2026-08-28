import 'package:automation_app/features/email_versand/presentation/widgets/email_empfaenger_feld.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eine uebernommene Adresse laesst sich zum Berichtigen wieder ins Feld holen
/// (§4.7).
///
/// Der Tippfehler faellt oft erst auf, wenn die Adresse schon als Kachel
/// dasteht. Ohne diesen Weg bliebe nur loeschen und alles neu tippen — bei
/// einer Adresse mit Aktenzeichen darin die Sorte Kleinarbeit, bei der der
/// zweite Tippfehler entsteht.
void main() {
  Future<List<String>> zeige(
    WidgetTester tester,
    List<String> adressen, {
    List<String>? entfernt,
    List<String>? hinzugefuegt,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailEmpfaengerFeld(
            titel: 'An',
            adressen: adressen,
            onHinzufuegen: (adresse) => hinzugefuegt?.add(adresse),
            onEntfernen: (adresse) => entfernt?.add(adresse),
          ),
        ),
      ),
    );
    return adressen;
  }

  String imFeld(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '';

  testWidgets('ein Klick auf die Kachel holt die Adresse ins Feld', (
    tester,
  ) async {
    final entfernt = <String>[];
    await zeige(tester, const ['schaden@huk.d'], entfernt: entfernt);

    await tester.tap(find.text('schaden@huk.d'));
    await tester.pump();

    // Aus der Reihe heraus und ins Feld hinein — sonst stuende sie zweimal da.
    expect(entfernt, ['schaden@huk.d']);
    expect(imFeld(tester), 'schaden@huk.d');
  });

  testWidgets('was schon im Feld steht, geht dabei nicht verloren', (
    tester,
  ) async {
    final hinzugefuegt = <String>[];
    await zeige(
      tester,
      const ['schaden@huk.de'],
      hinzugefuegt: hinzugefuegt,
      entfernt: <String>[],
    );

    await tester.enterText(find.byType(TextField), 'mandant@example.de');
    await tester.tap(find.text('schaden@huk.de'));
    await tester.pump();

    // Die angefangene Adresse wird uebernommen, bevor die angeklickte ins Feld
    // kommt: Eine Eingabe gegen eine andere zu tauschen waere keine Hilfe.
    expect(hinzugefuegt, ['mandant@example.de']);
    expect(imFeld(tester), 'schaden@huk.de');
  });

  testWidgets('das Kreuz entfernt weiterhin, ohne ins Feld zu holen', (
    tester,
  ) async {
    final entfernt = <String>[];
    await zeige(tester, const ['schaden@huk.de'], entfernt: entfernt);

    await tester.tap(find.byTooltip('Empfänger entfernen'));
    await tester.pump();

    expect(entfernt, ['schaden@huk.de']);
    expect(imFeld(tester), isEmpty);
  });
}
