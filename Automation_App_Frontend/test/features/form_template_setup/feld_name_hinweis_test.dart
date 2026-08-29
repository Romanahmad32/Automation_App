import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_name_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der Hinweis ist der sichtbare Teil der Erkennung: Dass
/// `FeldDatenquelleErkennung` einen mehrdeutigen Namen nicht bindet, nützt dem
/// Anwalt nur, wenn er den Grund im Vorlageneditor liest (§1.3). Die
/// Erkennungsregeln selbst prüft `feld_datenquelle_erkennung_test.dart` —
/// hier steht, was davon tatsächlich am Feld ankommt.
void main() {
  const feldKey = 'field_0';

  Future<void> zeige(
    WidgetTester tester,
    String feldname, {
    bool datenquelleGesetzt = false,
  }) async {
    final formGroup = FormGroup({
      feldKey: FormControl<String>(value: feldname),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: formGroup,
            child: FeldNameHinweis(
              formControlName: feldKey,
              datenquelleGesetzt: datenquelleGesetzt,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('nennt beide Angaben, die ein mehrdeutiger Name meint', (
    tester,
  ) async {
    await zeige(tester, 'VersicherungPlzOrt');

    expect(find.textContaining('PLZ und Ort'), findsOneWidget);
  });

  testWidgets('schweigt bei einem Namen, der eindeutig gebunden wird', (
    tester,
  ) async {
    await zeige(tester, 'Unfalldatum');

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('schweigt, sobald am Feld eine Datenquelle steht', (
    tester,
  ) async {
    // Eine gesetzte Quelle gewinnt immer über die Erkennung — dann ist der
    // Name egal und der Hinweis wäre nur noch Rauschen.
    await zeige(tester, 'VersicherungPlzOrt', datenquelleGesetzt: true);

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('folgt dem Namen, während der Anwalt ihn tippt', (tester) async {
    // Der Feldname entsteht im selben Formular; ein Hinweis, der erst nach dem
    // Speichern erschiene, käme zu spät.
    final formGroup = FormGroup({feldKey: FormControl<String>(value: 'Notiz')});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: formGroup,
            child: const FeldNameHinweis(
              formControlName: feldKey,
              datenquelleGesetzt: false,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);

    formGroup.control(feldKey).value = 'MandantVornameNachname';
    await tester.pump();

    expect(find.textContaining('Vorname und Nachname'), findsOneWidget);
  });
}
