import 'package:automation_app/core/general_widgets/form/reactive_text_eingabe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reactive_forms/reactive_forms.dart';

void main() {
  Future<void> baue(
    WidgetTester tester,
    FormGroup form, {
    ThemeData? theme,
    String name = 'feld',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: ReactiveTextEingabe<String>(
              formControlName: name,
              validationMessages: {'required': (_) => 'Pflichtfeld'},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Fehlermeldung erscheint erst, wenn das Feld berührt wurde', (
    tester,
  ) async {
    final form = FormGroup({
      'feld': FormControl<String>(validators: [Validators.required]),
    });
    await baue(tester, form);
    expect(find.text('Pflichtfeld'), findsNothing);

    form.control('feld').markAsTouched();
    await tester.pump();
    expect(find.text('Pflichtfeld'), findsOneWidget);
  });

  testWidgets('Wert fließt vom Control ins Feld und zurück', (tester) async {
    final form = FormGroup({'feld': FormControl<String>(value: 'Anfang')});
    await baue(tester, form);
    expect(find.text('Anfang'), findsOneWidget);

    form.control('feld').value = 'Neu';
    await tester.pump();
    expect(find.text('Neu'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Getippt');
    expect(form.control('feld').value, 'Getippt');
  });

  testWidgets('ein gesperrtes Control sperrt das Feld', (tester) async {
    final form = FormGroup({'feld': FormControl<String>(value: 'x')});
    await baue(tester, form);
    form.control('feld').markAsDisabled();
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('Theme-Dekoration (filled, fillColor) greift', (tester) async {
    final form = FormGroup({'feld': FormControl<String>()});
    await baue(
      tester,
      form,
      theme: ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF123456),
        ),
      ),
    );

    final dekoration = tester
        .widget<InputDecorator>(find.byType(InputDecorator))
        .decoration;
    expect(dekoration.filled, isTrue);
    expect(dekoration.fillColor, const Color(0xFF123456));
  });
}
