import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der eine Baustein für jedes Kennzeichenfeld der App — und damit die eine
/// Stelle, an der festliegt, was ein Kennzeichen ist.
///
/// Die beiden Hälften gehören zusammen und laufen leicht auseinander: Das Feld
/// **stellt die Konvention selbst her** (`hg-e1427` → `HG-E 1427`), also darf
/// der Validator nur beanstanden, was sich gar nicht lesen lässt. Verlangte er
/// mehr, beanstandete er Werte, die die App im selben Atemzug geradezieht — und
/// solche, die sie aus dem eigenen Register angeboten hat.
///
/// Die eine Ausnahme von der Toleranz ist die **Mehrdeutigkeit**: `HGE1427`
/// kann `HG-E 1427` oder `H-GE 1427` heissen, und das sind zwei Fahrzeuge.
/// Geraten wird da nichts — das Feld nennt die Lesarten und lässt den Wert
/// stehen, wie er getippt wurde.
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

    await tester.enterText(find.byType(TextField), 'hg-e1427');
    // Noch nicht umgeformt: Unter dem Cursor soll sich nichts bewegen, solange
    // getippt wird.
    expect(form.control(feldname).value, 'hg-e1427');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(form.control(feldname).value, 'HG-E 1427');
    expect(form.control(feldname).valid, isTrue);
  });

  /// Der Gegenfall dazu, und der Grund für die ganze Unterscheidung: Bei
  /// `HGE1427` steht nicht fest, wo das Unterscheidungszeichen endet. Das Feld
  /// darf sich hier **nicht** entscheiden — ein falsch aufgeteiltes
  /// Kennzeichen benennt ein anderes Fahrzeug und ginge unbemerkt in die
  /// Referenz und ins Anspruchsschreiben.
  testWidgets('lässt einen mehrdeutigen Wert stehen und nennt die Lesarten', (
    tester,
  ) async {
    final form = await zeige(tester);

    await tester.enterText(find.byType(TextField), 'HGE1427');
    FocusManager.instance.primaryFocus?.unfocus();
    form.control(feldname).markAsTouched();
    await tester.pump();

    expect(form.control(feldname).value, 'HGE1427');
    expect(form.control(feldname).valid, isFalse);
    expect(
      find.text('Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427'),
      findsOneWidget,
    );
    // Nicht die allgemeine Meldung: „so eingeben wie HG-E 1427" hätte der
    // Anwalt hier ja getan — er hat nur den Bindestrich weggelassen.
    expect(find.text(KennzeichenField.hinweis), findsNothing);
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
    test('jede eindeutig lesbare Schreibweise ist gültig', () {
      expect(pruefe('HG-E 1427'), isNull);
      expect(pruefe('hg-e1427'), isNull);
      expect(pruefe('GG XY 123'), isNull);
      expect(pruefe('HG-E1427H'), isNull);
      // Zwei Buchstaben lassen nur eine Aufteilung zu — kein Bindestrich nötig.
      expect(pruefe('he1427'), isNull);
    });

    test('Unlesbares meldet den eigenen Fehlerschlüssel', () {
      expect(pruefe('mein Auto'), {KennzeichenField.formatError: true});
      expect(KennzeichenField.formatError, 'kennzeichen');
    });

    /// Der Fehlerwert **ist** die Liste der Lesarten und nicht `true`:
    /// reactive_forms reicht ihn an die Meldungsfunktion durch, und nur so
    /// kann die Meldung sagen, zwischen welchen Werten zu wählen ist.
    test('Mehrdeutiges meldet die Lesarten als Fehlerwert', () {
      expect(pruefe('HGE1427'), {
        KennzeichenField.mehrdeutigError: ['HG-E 1427', 'H-GE 1427'],
      });
      expect(pruefe('FABC12'), {
        KennzeichenField.mehrdeutigError: ['FAB-C 12', 'FA-BC 12'],
      });
      expect(KennzeichenField.mehrdeutigError, 'kennzeichenMehrdeutig');
    });

    test('die Meldung nennt die Konvention mit Beispiel', () {
      final melden = KennzeichenField.meldungen[KennzeichenField.formatError]!;
      expect(melden(true), KennzeichenField.hinweis);
      expect(KennzeichenField.hinweis, contains('HG-E 1427'));
    });

    test('die Mehrdeutig-Meldung zählt die Lesarten auf', () {
      final melden =
          KennzeichenField.meldungen[KennzeichenField.mehrdeutigError]!;

      expect(
        melden(const ['HG-E 1427', 'H-GE 1427']),
        'Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427',
      );
      // Drei und mehr: Komma dazwischen, „oder" vor der letzten.
      expect(
        melden(const ['A-BC 1', 'AB-C 1', 'ABC-D 1']),
        'Mehrdeutig, bitte mit Bindestrich: A-BC 1, AB-C 1 oder ABC-D 1',
      );
    });
  });

  /// Für die Prüfstellen ausserhalb von reactive_forms (Chip-Editor am
  /// Mandanten, Bearbeiten-Dialog eines Vorgangs). Sie sollen dieselbe Auskunft
  /// geben wie das Formular — sonst hängt es am Eingabeort, ob der Anwalt
  /// erfährt, was der App fehlt.
  group('beanstandung', () {
    test('eindeutig ist in Ordnung, Unlesbares nennt die Konvention', () {
      expect(KennzeichenField.beanstandung('hg-e 1427'), isNull);
      expect(
        KennzeichenField.beanstandung('mein Auto'),
        KennzeichenField.hinweis,
      );
    });

    test('mehrdeutig nennt die Lesarten', () {
      expect(
        KennzeichenField.beanstandung('HGE1427'),
        'Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427',
      );
    });
  });
}
