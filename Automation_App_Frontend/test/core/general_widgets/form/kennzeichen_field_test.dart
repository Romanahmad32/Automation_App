import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der eine Baustein für jedes Kennzeichenfeld der App — und damit die eine
/// Stelle, an der festliegt, was ein Kennzeichen ist.
///
/// Die beiden Hälften gehören zusammen und laufen leicht auseinander: Das Feld
/// **stellt die Konvention selbst her** (`HGE1427` → `HG-E 1427`), also darf
/// der Validator nur beanstanden, was sich gar nicht lesen lässt. Verlangte er
/// mehr, beanstandete er Werte, die die App im selben Atemzug geradezieht — und
/// solche, die sie aus dem eigenen Register angeboten hat.
void main() {
  const feldname = 'kennzeichen';

  FormGroup gruppe() => FormGroup({
    feldname: FormControl<String>(
      validators: [Validators.delegate(KennzeichenField.validator)],
    ),
  });

  Future<FormGroup> zeige(
    WidgetTester tester, {
    List<AuswahlKandidat> kandidaten = const [],
  }) async {
    final form = gruppe();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: KennzeichenField(
              formControlName: feldname,
              kandidaten: kandidaten,
            ),
          ),
        ),
      ),
    );
    return form;
  }

  /// Setzt einen Wert **und** rührt das Feld an: Ohne `touched` zeigt
  /// reactive_forms den Fehler nicht — der Test prüfte dann die Vorgabe des
  /// Formulars statt die Meldung.
  Future<void> trageEin(
    WidgetTester tester,
    FormGroup form,
    String wert,
  ) async {
    form.control(feldname)
      ..value = wert
      ..markAsTouched();
    await tester.pump();
  }

  testWidgets('beanstandet, was sich nicht als Kennzeichen lesen lässt', (
    tester,
  ) async {
    final form = await zeige(tester);

    await trageEin(tester, form, 'mein Auto');

    expect(form.control(feldname).valid, isFalse);
    expect(find.text(KennzeichenField.hinweis), findsOneWidget);
  });

  testWidgets('nimmt ein Kennzeichen in der Konvention an', (tester) async {
    final form = await zeige(tester);

    await trageEin(tester, form, 'HG-E 1427');

    expect(form.control(feldname).valid, isTrue);
    expect(find.text(KennzeichenField.hinweis), findsNothing);
  });

  /// Ob ein Kennzeichen Pflicht ist, entscheidet der Required-Validator
  /// daneben — dieses Feld sagt dazu nichts.
  testWidgets('lässt ein leeres Feld gelten', (tester) async {
    final form = await zeige(tester);

    await trageEin(tester, form, '   ');

    expect(form.control(feldname).valid, isTrue);
    expect(find.text(KennzeichenField.hinweis), findsNothing);
  });

  testWidgets('stellt die Konvention beim Verlassen des Felds selbst her', (
    tester,
  ) async {
    final form = await zeige(tester);

    await tester.enterText(find.byType(TextField), 'HGE1427');
    // Noch nicht umgeformt: Unter dem Cursor soll sich nichts bewegen, solange
    // getippt wird.
    expect(form.control(feldname).value, 'HGE1427');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(form.control(feldname).value, 'HG-E 1427');
    expect(form.control(feldname).valid, isTrue);
  });

  testWidgets('trägt ohne Kandidaten kein Auswahlsymbol', (tester) async {
    await zeige(tester);

    expect(find.byIcon(Icons.list_alt), findsNothing);
  });

  testWidgets('bietet die bekannten Kennzeichen zur Wahl an', (tester) async {
    final form = await zeige(
      tester,
      kandidaten: const [AuswahlKandidat('F-AB 12', 'aus dem Register')],
    );

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    expect(find.text('Kennzeichen wählen'), findsOneWidget);
    await tester.tap(find.text('F-AB 12'));
    await tester.pumpAndSettle();

    expect(form.control(feldname).value, 'F-AB 12');
  });

  group('validator', () {
    Map<String, dynamic>? pruefe(String? wert) =>
        KennzeichenField.validator(FormControl<String>(value: wert));

    test('leere Werte sind gültig', () {
      expect(pruefe(null), isNull);
      expect(pruefe(''), isNull);
      expect(pruefe('   '), isNull);
    });

    /// Auch die Schreibvarianten: Was das Feld normalisieren kann, ist gültig —
    /// sonst stünde die Beanstandung an einem Wert, den es gleich darauf selbst
    /// geradezieht.
    test('jede lesbare Schreibweise ist gültig', () {
      expect(pruefe('HG-E 1427'), isNull);
      expect(pruefe('hge1427'), isNull);
      expect(pruefe('GG XY 123'), isNull);
      expect(pruefe('HG-E1427H'), isNull);
    });

    test('Unlesbares meldet den eigenen Fehlerschlüssel', () {
      expect(pruefe('mein Auto'), {KennzeichenField.formatError: true});
      expect(KennzeichenField.formatError, 'kennzeichen');
    });

    test('die Meldung nennt die Konvention mit Beispiel', () {
      final melden = KennzeichenField.meldungen[KennzeichenField.formatError]!;
      expect(melden(true), KennzeichenField.hinweis);
      expect(KennzeichenField.hinweis, contains('HG-E 1427'));
    });
  });
}
