import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_text_field.dart';
import 'package:automation_app/core/general_widgets/form/feld_schluessel.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Jedes Formularfeld trägt `feld-<formControlName>` — auch leer, und auf dem
/// innersten `TextField`, damit Eingabe per Key ankommt.
void main() {
  Future<FormGroup> baue(WidgetTester tester) async {
    final form = FormGroup({
      'mandantVorname': FormControl<String>(),
      'unfalldatum': FormControl<String>(),
      'kennzeichen': FormControl<String>(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: const Column(
              children: [
                GeneralTextField<String>(
                  formControlName: 'mandantVorname',
                  labelText: 'Vorname',
                ),
                GermanDateField(formControlName: 'unfalldatum'),
                AuswahlTextField(
                  formControlName: 'kennzeichen',
                  kandidaten: <AuswahlKandidat>[],
                  dialogTitel: 'Kennzeichen wählen',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return form;
  }

  testWidgets('alle drei Feldbausteine tragen den Key feld-<Name>', (
    tester,
  ) async {
    await baue(tester);

    for (final name in ['mandantVorname', 'unfalldatum', 'kennzeichen']) {
      expect(find.byKey(ValueKey('feld-$name')), findsOneWidget, reason: name);
    }
  });

  testWidgets('der Key sitzt auf dem TextField und nimmt Eingaben an', (
    tester,
  ) async {
    final form = await baue(tester);

    final feld = find.byKey(FeldSchluessel.fuer('mandantVorname')!);
    expect(tester.widget(feld), isA<TextField>());

    await tester.enterText(feld, 'Erika');

    expect(form.control('mandantVorname').value, 'Erika');
  });

  test('ohne Namen gibt es keinen Key', () {
    expect(FeldSchluessel.fuer(null), isNull);
    expect(FeldSchluessel.fuer(''), isNull);
  });
}
