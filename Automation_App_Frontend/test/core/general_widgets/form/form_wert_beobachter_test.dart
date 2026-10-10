import 'package:automation_app/core/general_widgets/form/form_wert_beobachter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// #133: Was in den letzten Sekunden vor dem Verlassen getippt wurde, darf
/// nicht verloren gehen. Der Beobachter meldet deshalb seit hier auch aus
/// `dispose` heraus — aber nur, wenn zu diesem Zeitpunkt noch eine
/// unentprellte Änderung ansteht; sonst gäbe es dieselbe Meldung doppelt.
///
/// Dazu die Dauer selbst: Seit die Meldung die Sicherung am Vorgang unmittelbar
/// auslöst, ist die Entprellung die einzige Verzögerung dazwischen — sie liegt
/// deshalb bei 300 ms statt bei zwei Sekunden.
void main() {
  late FormGroup form;
  late List<Map<String, String>> meldungen;

  setUp(() {
    form = FormGroup({'name': FormControl<String>(value: '')});
    meldungen = [];
  });

  Widget bauen({required bool zeigen}) => MaterialApp(
    home: Scaffold(
      body: zeigen
          ? FormWertBeobachter(
              formGroup: form,
              onWerteGeaendert: meldungen.add,
              child: const SizedBox(),
            )
          : const SizedBox(),
    ),
  );

  testWidgets('meldet eine ausstehende Änderung beim Verlassen', (
    tester,
  ) async {
    await tester.pumpWidget(bauen(zeigen: true));

    form.control('name').updateValue('Meier');
    await tester.pump(); // Stream-Ereignis zustellen
    await tester.pump(const Duration(milliseconds: 100)); // vor der Entprellung

    expect(meldungen, isEmpty, reason: 'die Entprellung läuft noch');

    // Das Widget aus dem Baum nehmen — löst dispose() aus, so wie ein
    // Seitenwechsel es täte.
    await tester.pumpWidget(bauen(zeigen: false));

    expect(meldungen, [
      {'name': 'Meier'},
    ]);
  });

  testWidgets('ohne ausstehende Änderung keine Doppelmeldung', (tester) async {
    await tester.pumpWidget(bauen(zeigen: true));

    form.control('name').updateValue('Meier');
    await tester.pump();
    // Die Entprellung läuft vollständig ab — die Meldung ist schon raus.
    await tester.pump(
      FormWertBeobachter.standardEntprellung + const Duration(milliseconds: 50),
    );

    expect(meldungen, [
      {'name': 'Meier'},
    ]);

    await tester.pumpWidget(bauen(zeigen: false));

    expect(meldungen, [
      {'name': 'Meier'},
    ], reason: 'schon gemeldet — dispose darf sie nicht wiederholen');
  });

  testWidgets('ohne jede Änderung bleibt dispose stumm', (tester) async {
    await tester.pumpWidget(bauen(zeigen: true));

    await tester.pumpWidget(bauen(zeigen: false));

    expect(meldungen, isEmpty);
  });

  /// Die Dauer selbst, benannt statt nebenbei mitgeprüft: An ihr hängt, wie
  /// viel ein Absturz oder ein hastiger Klick kostet — sie zu erhöhen ist eine
  /// Entscheidung, keine Formalie.
  testWidgets('meldet 300 ms nach dem letzten Tastendruck', (tester) async {
    expect(
      FormWertBeobachter.standardEntprellung,
      const Duration(milliseconds: 300),
    );

    await tester.pumpWidget(bauen(zeigen: true));

    form.control('name').updateValue('Mei');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(meldungen, isEmpty, reason: 'noch nicht abgelaufen');

    // Ein weiterer Tastendruck setzt die Entprellung zurück.
    form.control('name').updateValue('Meier');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(meldungen, isEmpty, reason: 'von vorn gezählt');

    await tester.pump(const Duration(milliseconds: 100));

    expect(meldungen, [
      {'name': 'Meier'},
    ]);
  });
}
