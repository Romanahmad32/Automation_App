import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Das Feld ist ein **Angebot**: Es lässt sich tippen wie jedes andere, und das
/// Symbol daneben zeigt, was die App schon weiß. Deshalb hängen hier zwei
/// Aussagen, die leicht auseinanderlaufen — kein Symbol ohne Kandidaten, und
/// die freie Eingabe im Dialog kommt genauso an wie eine ausgewählte.
void main() {
  const feldname = 'Fahrzeug';

  FormGroup gruppe() => FormGroup({feldname: FormControl<String>(value: null)});

  Future<FormGroup> zeige(
    WidgetTester tester, {
    required List<AuswahlKandidat> kandidaten,
    String Function(String)? normalisiere,
  }) async {
    final form = gruppe();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: AuswahlTextField(
              formControlName: feldname,
              labelText: 'Kennzeichen',
              kandidaten: kandidaten,
              dialogTitel: 'Kennzeichen wählen',
              normalisiere: normalisiere,
            ),
          ),
        ),
      ),
    );
    return form;
  }

  Object? imFeld(FormGroup form) => form.control(feldname).value;

  /// Das Textfeld im Dialog — nicht das des Formulars darunter.
  Finder freieEingabe() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets('ohne Kandidaten trägt das Feld kein Auswahlsymbol', (
    tester,
  ) async {
    await zeige(tester, kandidaten: const []);

    expect(find.byIcon(Icons.list_alt), findsNothing);
  });

  testWidgets('mit Kandidaten öffnet das Symbol die Liste', (tester) async {
    await zeige(
      tester,
      kandidaten: const [
        AuswahlKandidat('HG-E 1427', 'aus den Vorgangsdaten'),
        AuswahlKandidat('F-AB 12', 'aus dem Mandantenregister'),
      ],
    );

    expect(find.byIcon(Icons.list_alt), findsOneWidget);

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();

    expect(find.text('Kennzeichen wählen'), findsOneWidget);
    expect(find.text('HG-E 1427'), findsOneWidget);
    // Die Herkunft steht als Untertitel dabei: Der Anwalt sieht, welchem
    // Bestand er den Wert verdankt, bevor er ihn übernimmt.
    expect(find.text('aus dem Mandantenregister'), findsOneWidget);
  });

  testWidgets('ein gewählter Kandidat landet im Control', (tester) async {
    final form = await zeige(
      tester,
      kandidaten: const [
        AuswahlKandidat('HG-E 1427', 'aus den Vorgangsdaten'),
        AuswahlKandidat('F-AB 12', 'aus dem Mandantenregister'),
      ],
    );

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F-AB 12'));
    await tester.pumpAndSettle();

    expect(imFeld(form), 'F-AB 12');
    // Sonst zeigte ein ungültiger gewählter Wert seinen Fehler erst, wenn das
    // Feld auch noch angefasst wurde.
    expect(form.control(feldname).touched, isTrue);
  });

  testWidgets('die freie Eingabe wird normalisiert übernommen', (tester) async {
    final form = await zeige(
      tester,
      kandidaten: const [AuswahlKandidat('F-AB 12', 'aus dem Register')],
      // Steht hier fuer jede Konvention, die ein Feature mitbringt (beim
      // Kennzeichen `normalizeKennzeichen`): geprueft wird, dass sie auf die
      // freie Eingabe angewandt wird — nicht, was sie rechnet.
      normalisiere: (eingabe) => eingabe.toUpperCase(),
    );

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    await tester.enterText(freieEingabe(), ' hg-e 1427 ');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    // Gestutzt (das macht der Dialog) und normalisiert (das macht das Feature).
    expect(imFeld(form), 'HG-E 1427');
  });

  /// „Übernehmen" auf einem leeren Feld wäre sonst ein zweites „Abbrechen" —
  /// und der Anwalt stünde vor einem Dialog, der auf zwei Knöpfe gleich
  /// reagiert.
  testWidgets('eine leere freie Eingabe schliesst den Dialog nicht', (
    tester,
  ) async {
    final form = await zeige(
      tester,
      kandidaten: const [AuswahlKandidat('F-AB 12', 'aus dem Register')],
    );

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(imFeld(form), isNull);
  });

  testWidgets(
    'eine direkt getippte Eingabe wird beim Verlassen des Felds normalisiert',
    (tester) async {
      // Steht hier fuer jede Konvention, die ein Feature mitbringt (beim
      // Kennzeichen `normalizeKennzeichen`) — geprueft wird, dass sie auch
      // auf die direkt getippte Eingabe angewandt wird, nicht nur auf die
      // freie Eingabe im Dialog.
      final form = await zeige(
        tester,
        kandidaten: const [AuswahlKandidat('F-AB 12', 'aus dem Register')],
        normalisiere: (eingabe) => eingabe.toUpperCase(),
      );

      await tester.enterText(find.byType(TextField).first, 'hg-e 1427');
      // Noch nicht normalisiert — erst beim Verlassen des Felds, nicht bei
      // jedem Tastendruck.
      expect(imFeld(form), 'hg-e 1427');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(imFeld(form), 'HG-E 1427');
    },
  );

  testWidgets(
    'eine leere direkt getippte Eingabe bleibt beim Verlassen des Felds leer',
    (tester) async {
      final form = await zeige(
        tester,
        kandidaten: const [AuswahlKandidat('F-AB 12', 'aus dem Register')],
        normalisiere: (eingabe) => eingabe.toUpperCase(),
      );

      // Erst füllen, dann leeren — sonst bliebe der Wert `null` und der
      // Test prüfte gar keine Änderung.
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.enterText(find.byType(TextField).first, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(imFeld(form), '');
    },
  );

  testWidgets('Abbrechen lässt den Wert stehen', (tester) async {
    final form = await zeige(
      tester,
      kandidaten: const [AuswahlKandidat('F-AB 12', 'aus dem Register')],
    );
    form.control(feldname).value = 'HG-E 1427';
    await tester.pump();

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(imFeld(form), 'HG-E 1427');
  });
}
