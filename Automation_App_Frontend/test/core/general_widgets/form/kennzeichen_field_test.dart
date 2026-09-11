import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der eine Baustein für jedes Kennzeichenfeld der App — und damit die eine
/// Stelle, an der festliegt, wie die App mit einem Kennzeichen umgeht.
///
/// **Sperren tut er nichts** (#130). Welche Fahrzeuge in eine Kanzlei kommen,
/// entscheidet nicht die App: Versicherungskennzeichen (E-Scooter), Behörden-,
/// Kurzzeit- und Auslandskennzeichen sind Alltag und passen alle nicht ins
/// Pkw-Schema. Vor #130 hing hier ein Validator, der genau das durchfallen
/// liess — ein E-Scooter-Mandat war damit weder zu starten noch zu beschreiben.
///
/// Was bleibt: Die Konvention wird **hergestellt**, wo die Lesart feststeht
/// (`hg-e1427` → `HG-E 1427`, §4.2), und was auffällt, steht als Hinweis unter
/// dem Feld — sichtbar, ohne dass jemand das Feld anfassen muss.
///
/// Die Mehrdeutigkeit bleibt der eigene Fall: `HGE1427` kann `HG-E 1427` oder
/// `H-GE 1427` heissen, und das sind zwei Fahrzeuge. Geraten wird da nichts —
/// der Wert bleibt stehen, wie er getippt wurde, und der Hinweis nennt beide.
void main() {
  const feldname = 'kennzeichen';

  Future<FormGroup> zeige(
    WidgetTester tester, {
    List<AuswahlKandidat> kandidaten = const [],
    String? vorbelegt,
    String? helperText,
  }) async {
    final form = FormGroup({feldname: FormControl<String>(value: vorbelegt)});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: KennzeichenField(
              formControlName: feldname,
              kandidaten: kandidaten,
              helperText: helperText,
            ),
          ),
        ),
      ),
    );
    return form;
  }

  /// Der Kern des Issues: Ein Wert, den die App nicht als Pkw-Kennzeichen
  /// liest, hält **nichts** auf — er bekommt nur seinen Hinweis.
  testWidgets('nimmt ein Versicherungskennzeichen an und merkt es an', (
    tester,
  ) async {
    final form = await zeige(tester, vorbelegt: '123 ABC');

    expect(form.valid, isTrue);
    expect(form.control(feldname).value, '123 ABC');
    expect(find.text(KennzeichenField.unbekanntHinweis), findsOneWidget);
  });

  /// Ohne Anfassen: Ein vorbelegter Wert wird nie `touched`, und ein Hinweis,
  /// den man erst durch Anfassen zu sehen bekommt, schweigt genau dort, wo er
  /// gebraucht wird (#130).
  testWidgets('zeigt den Hinweis an einem vorbelegten Wert ungefragt', (
    tester,
  ) async {
    final form = await zeige(tester, vorbelegt: 'mein Auto');

    expect(form.control(feldname).touched, isFalse);
    expect(find.text(KennzeichenField.unbekanntHinweis), findsOneWidget);
  });

  testWidgets('sagt zu einem Kennzeichen in der Konvention nichts', (
    tester,
  ) async {
    await zeige(tester, vorbelegt: 'HG-E 1427');

    expect(find.text(KennzeichenField.unbekanntHinweis), findsNothing);
  });

  testWidgets('lässt ein leeres Feld unkommentiert', (tester) async {
    await zeige(tester, vorbelegt: '   ');

    expect(find.text(KennzeichenField.unbekanntHinweis), findsNothing);
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
  });

  /// Der Gegenfall, und der Grund für die ganze Unterscheidung: Bei `HGE1427`
  /// steht nicht fest, wo das Unterscheidungszeichen endet. Das Feld darf sich
  /// hier **nicht** entscheiden — ein falsch aufgeteiltes Kennzeichen benennt
  /// ein anderes Fahrzeug und ginge unbemerkt in die Referenz und ins
  /// Anspruchsschreiben. Aufhalten darf es die Arbeit trotzdem nicht.
  testWidgets('lässt einen mehrdeutigen Wert stehen und nennt die Lesarten', (
    tester,
  ) async {
    final form = await zeige(tester);

    await tester.enterText(find.byType(TextField), 'HGE1427');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(form.control(feldname).value, 'HGE1427');
    expect(form.valid, isTrue);
    expect(
      find.text('Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427'),
      findsOneWidget,
    );
    // Nicht der allgemeine Hinweis: „nicht erkannt" wäre hier falsch — die App
    // erkennt zwei Lesarten und weiss nur nicht, welche gemeint ist.
    expect(find.text(KennzeichenField.unbekanntHinweis), findsNothing);
  });

  /// Der Hinweis hört auf den Wert und damit auf **jeden Tastendruck**. Er
  /// darf deshalb nicht bei jedem Zwischenstand anschlagen: `HG-E 1427` wird
  /// Zeichen für Zeichen getippt, und acht dieser neun Stände sind für sich
  /// genommen kein Kennzeichen.
  testWidgets('schweigt, solange ein Kennzeichen noch entstehen kann', (
    tester,
  ) async {
    await zeige(tester);

    for (final zwischenstand in ['H', 'HG', 'HG-', 'HG-E', 'HG-E 1']) {
      await tester.enterText(find.byType(TextField), zwischenstand);
      await tester.pump();
      expect(
        find.text(KennzeichenField.unbekanntHinweis),
        findsNothing,
        reason: 'bei „$zwischenstand" ist noch nichts entschieden',
      );
    }
  });

  /// Der Gegenfall dazu, damit die Stille nicht zur Regel wird: Aus `123` wird
  /// nie ein Pkw-Kennzeichen, also steht der Hinweis sofort da.
  testWidgets('sagt sofort etwas, wo kein Kennzeichen mehr entstehen kann', (
    tester,
  ) async {
    await zeige(tester);

    await tester.enterText(find.byType(TextField), '123 ');
    await tester.pump();

    expect(find.text(KennzeichenField.unbekanntHinweis), findsOneWidget);
  });

  /// Die Hilfszeile des Aufrufers darf der Hinweis nicht verdrängen: Im
  /// Ausfüllschritt steht dort „* Pflichtfeld · Vorbelegt …", und beide
  /// Auskünfte werden gerade an einem ungewöhnlichen Wert gebraucht.
  testWidgets('stellt den Hinweis neben die Zeile des Aufrufers', (
    tester,
  ) async {
    await zeige(
      tester,
      vorbelegt: '123 ABC',
      helperText: '* Pflichtfeld · Vorbelegt aus der Zentralruf-Antwort',
    );

    expect(
      find.text(
        '* Pflichtfeld · Vorbelegt aus der Zentralruf-Antwort · '
        '${KennzeichenField.unbekanntHinweis}',
      ),
      findsOneWidget,
    );
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

  /// Die Auskunft selbst — sie ist dieselbe an jedem Eingabeort (Formular,
  /// Chip-Editor am Mandanten, Bearbeiten-Dialog eines Vorgangs). Sonst hinge
  /// es am Ort, ob der Anwalt erfährt, was der App aufgefallen ist.
  group('beanstandung', () {
    test('leere Werte sind unauffällig', () {
      expect(KennzeichenField.beanstandung(''), isNull);
      expect(KennzeichenField.beanstandung('   '), isNull);
    });

    /// Was das Feld normalisieren kann, ist unauffällig — sonst stünde ein
    /// Hinweis an einem Wert, den es gleich darauf selbst geradezieht.
    test('jede eindeutig lesbare Schreibweise ist unauffällig', () {
      expect(KennzeichenField.beanstandung('HG-E 1427'), isNull);
      expect(KennzeichenField.beanstandung('hg-e1427'), isNull);
      expect(KennzeichenField.beanstandung('GG XY 123'), isNull);
      expect(KennzeichenField.beanstandung('HG-E1427H'), isNull);
      // Zwei Buchstaben lassen nur eine Aufteilung zu — kein Bindestrich nötig.
      expect(KennzeichenField.beanstandung('he1427'), isNull);
    });

    /// Ein Zwischenstand beim Tippen ist noch keine Beanstandung.
    test('ein halb getipptes Kennzeichen bleibt unkommentiert', () {
      expect(KennzeichenField.beanstandung('HG'), isNull);
      expect(KennzeichenField.beanstandung('HG-'), isNull);
      expect(KennzeichenField.beanstandung('HG-E'), isNull);
      expect(KennzeichenField.beanstandung('HG-E 1'), isNull);
    });

    /// Die Bauarten namentlich: Keine davon ist ein Fehler, jede bekommt
    /// denselben Hinweis — „wird übernommen, wie eingegeben".
    test('fremde Bauarten werden angemerkt, nicht abgelehnt', () {
      for (final wert in [
        '123 ABC', // Versicherungskennzeichen (E-Scooter, Moped)
        '123-ABC',
        'Y-123456', // Bundeswehr
        'X-1234', // NATO
        'THW-12345',
        '0 12-345', // Diplomatenkennzeichen
        'HG-04711', // Kurzzeitkennzeichen, fünf Ziffern
        'AB-123-CD', // Frankreich
        '1-ABC-234', // Belgien
        'AB 12345', // Polen
        'mein Auto',
      ]) {
        expect(
          KennzeichenField.beanstandung(wert),
          KennzeichenField.unbekanntHinweis,
          reason: '$wert ist kein Pkw-Kennzeichen, aber ein gültiger Wert',
        );
      }
    });

    test('mehrdeutig nennt die Lesarten', () {
      expect(
        KennzeichenField.beanstandung('HGE1427'),
        'Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427',
      );
      expect(
        KennzeichenField.beanstandung('FABC12'),
        'Mehrdeutig, bitte mit Bindestrich: FAB-C 12 oder FA-BC 12',
      );
    });

    test('drei Lesarten: Komma dazwischen, „oder" vor der letzten', () {
      expect(
        KennzeichenField.mehrdeutigHinweis(const [
          'A-BC 1',
          'AB-C 1',
          'ABC-D 1',
        ]),
        'Mehrdeutig, bitte mit Bindestrich: A-BC 1, AB-C 1 oder ABC-D 1',
      );
    });
  });
}
