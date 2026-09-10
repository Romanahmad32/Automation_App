import 'package:automation_app/core/general_widgets/form/formular_fehler_hinweis.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Zeile über einem gesperrten Knopf. Ihr ganzer Zweck ist, dass niemand
/// mehr vor einem toten Knopf steht und rät (#35 Teil 3, #130).
///
/// Der Härtefall ist der **unberührte** Wert: reactive_forms zeigt einen Fehler
/// am Feld erst, wenn es angefasst wurde — ein vorbelegter Wert wird das nie,
/// und ein gesperrter Knopf nimmt keinen Fokus, man verlässt das Feld also auch
/// nach dem Tippen nicht. Diese Zeile hört deshalb auf den **Wert**.
void main() {
  Future<FormGroup> zeige(
    WidgetTester tester,
    FormGroup form, {
    Map<String, String> beschriftungen = const {},
    List<String>? felder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: FormularFehlerHinweis(
              felder: felder,
              beschriftungen: beschriftungen,
            ),
          ),
        ),
      ),
    );
    return form;
  }

  testWidgets('schweigt, solange das Formular gültig ist', (tester) async {
    await zeige(
      tester,
      FormGroup({'name': FormControl<String>(value: 'Meier')}),
    );

    expect(find.byType(Text), findsNothing);
  });

  /// Der Wortlaut aus #35 bleibt: „fehlt" ist die richtige Auskunft zu einem
  /// leeren Pflichtfeld, „zu berichtigen" wäre daneben.
  testWidgets('zählt die leeren Pflichtfelder wie bisher auf', (tester) async {
    await zeige(
      tester,
      FormGroup({
        'nachname': FormControl<String>(validators: [Validators.required]),
        'ort': FormControl<String>(validators: [Validators.required]),
      }),
      beschriftungen: {'nachname': 'Nachname', 'ort': 'Ort'},
    );

    expect(find.text('2 Pflichtfelder fehlen:'), findsOneWidget);
    expect(find.text('Nachname'), findsOneWidget);
    expect(find.text('Ort'), findsOneWidget);
  });

  /// Das ist der Zuwachs aus #130: Vorher kannte die Zeile nur `required` —
  /// ein halb getipptes Datum sperrte den Knopf wortlos.
  testWidgets('benennt auch ein Feld, das nur falsch ausgefüllt ist', (
    tester,
  ) async {
    final form = FormGroup({
      'unfalldatum': FormControl<String>(
        value: '1.1.',
        validators: [GermanDateField.validator()],
      ),
    });

    await zeige(tester, form, beschriftungen: {'unfalldatum': 'Unfalldatum'});

    expect(form.control('unfalldatum').touched, isFalse);
    expect(find.text('1 Feld ist noch zu berichtigen:'), findsOneWidget);
    expect(
      find.text('Unfalldatum: Datum im Format TT.MM.JJJJ angeben'),
      findsOneWidget,
    );
  });

  /// Zwei verschiedene Auskünfte, zwei Zeilen — „fehlt" und „falsch" in einer
  /// Aufzählung zu mischen, hiesse dem Anwalt beides als dasselbe zu erklären.
  testWidgets('trennt Fehlendes von Falschem', (tester) async {
    await zeige(
      tester,
      FormGroup({
        'nachname': FormControl<String>(validators: [Validators.required]),
        'email': FormControl<String>(
          value: 'kein-at-zeichen',
          validators: [Validators.email],
        ),
      }),
    );

    expect(find.text('1 Pflichtfeld fehlt:'), findsOneWidget);
    expect(find.text('1 Feld ist noch zu berichtigen:'), findsOneWidget);
    expect(find.text('email: keine gültige E-Mail-Adresse'), findsOneWidget);
  });

  /// Ohne Beschriftung steht der Control-Name da — bei Vorlagenfeldern ist er
  /// schon die Beschriftung, und ein Feld ganz zu verschweigen wäre schlimmer
  /// als ein technischer Name.
  testWidgets('nimmt den Control-Namen, wenn keine Beschriftung da ist', (
    tester,
  ) async {
    await zeige(
      tester,
      FormGroup({
        'kennzeichenGegner': FormControl<String>(
          validators: [Validators.required],
        ),
      }),
    );

    expect(find.text('kennzeichenGegner'), findsOneWidget);
  });

  /// Für Formulare mit Controls, die gerade gar nicht auf dem Schirm sind
  /// (`FormTemplateBuilder`, eingeklappte Felder): Was nicht dabeisteht, wird
  /// nicht genannt — ein Sprung dorthin fände kein Feld.
  testWidgets('meldet nur die genannten Felder', (tester) async {
    await zeige(
      tester,
      FormGroup({
        'sichtbar': FormControl<String>(validators: [Validators.required]),
        'zugeklappt': FormControl<String>(validators: [Validators.required]),
      }),
      felder: ['sichtbar'],
    );

    expect(find.text('1 Pflichtfeld fehlt:'), findsOneWidget);
    expect(find.text('zugeklappt'), findsNothing);
  });

  testWidgets('springt beim Anklicken in sein Feld', (tester) async {
    final form = FormGroup({
      'nachname': FormControl<String>(validators: [Validators.required]),
    });

    // Mit echtem Feld daneben: Der Sprung ist nur dann etwas wert, wenn am
    // Ende der Cursor in einem gebauten Eingabefeld steht.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: Column(
              children: [
                ReactiveTextField<String>(formControlName: 'nachname'),
                const FormularFehlerHinweis(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('nachname'));
    await tester.pump();

    final control = form.control('nachname') as FormControl<String>;
    expect(control.hasFocus, isTrue);
  });
}
