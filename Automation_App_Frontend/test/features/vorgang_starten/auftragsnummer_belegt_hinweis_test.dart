import 'package:automation_app/features/vorgang_starten/presentation/widgets/auftragsnummer_belegt_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// §6.3: „Eine doppelte Nummer warnt, sperrt nicht." Der Hinweis ist der
/// sichtbare Teil davon — ob das Feld dabei tatsächlich gültig **bleibt**
/// (kein `FormControl`-Validator dahinter), prüft der letzte Test hier extra,
/// weil genau das der Unterschied zur RVG-Wert-Prüfung ist, die das Speichern
/// sperrt (`word_automation`).
void main() {
  Future<FormGroup> zeige(
    WidgetTester tester, {
    required List<int> belegteNummern,
    String? jahr,
    String auftragsnummer = '',
  }) async {
    final formGroup = FormGroup({
      'auftragsnummer': FormControl<String>(
        value: auftragsnummer,
        validators: [Validators.required, Validators.number()],
      ),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: formGroup,
            child: AuftragsnummerBelegtHinweis(
              belegteNummern: belegteNummern,
              jahr: jahr,
            ),
          ),
        ),
      ),
    );
    return formGroup;
  }

  testWidgets('schweigt ohne geladenen Bestand', (tester) async {
    await zeige(
      tester,
      belegteNummern: const [],
      jahr: null,
      auftragsnummer: '5',
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('schweigt bei einer freien Nummer', (tester) async {
    await zeige(
      tester,
      belegteNummern: const [1, 4, 5, 6],
      jahr: '2026',
      auftragsnummer: '7',
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('nennt Nummer und Jahrgang bei einer belegten Nummer', (
    tester,
  ) async {
    await zeige(
      tester,
      belegteNummern: const [1, 4, 5, 6],
      jahr: '2026',
      auftragsnummer: '5',
    );

    expect(
      find.text('Nummer 5 ist im Jahrgang 2026 schon vergeben.'),
      findsOneWidget,
    );
  });

  testWidgets('folgt dem Feldwert, während der Anwalt tippt', (tester) async {
    final formGroup = await zeige(
      tester,
      belegteNummern: const [1, 4, 5, 6],
      jahr: '2026',
      auftragsnummer: '7',
    );
    expect(find.byType(Text), findsNothing);

    formGroup.control('auftragsnummer').value = '5';
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('schon vergeben'), findsOneWidget);

    formGroup.control('auftragsnummer').value = '9';
    await tester.pump();
    await tester.pump();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('die Warnung setzt keinen Validator: das Feld bleibt gültig', (
    tester,
  ) async {
    final formGroup = await zeige(
      tester,
      belegteNummern: const [1, 4, 5, 6],
      jahr: '2026',
      auftragsnummer: '5',
    );

    expect(
      find.text('Nummer 5 ist im Jahrgang 2026 schon vergeben.'),
      findsOneWidget,
    );
    expect(formGroup.control('auftragsnummer').valid, isTrue);
    expect(formGroup.valid, isTrue);
  });
}
