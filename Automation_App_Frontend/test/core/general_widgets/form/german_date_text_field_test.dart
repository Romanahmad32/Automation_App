import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_text_field.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Das Datumsfeld ohne reactive_forms (#171): dieselbe Prüfung und derselbe
/// Kalender wie `GermanDateField` — aber ein Formatfehler sperrt nichts, er
/// steht als Hinweis unter dem Feld.
void main() {
  const formatSatz = 'Datum im Format TT.MM.JJJJ angeben';

  Future<({TextEditingController controller, List<String> gemeldet})> zeige(
    WidgetTester tester, {
    String text = '',
    String? helperText,
    DateTime? firstDate,
    DateTime? lastDate,
    bool enabled = true,
  }) async {
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    final gemeldet = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GermanDateTextField(
                controller: controller,
                labelText: 'Tatdatum',
                helperText: helperText,
                firstDate: firstDate,
                lastDate: lastDate,
                enabled: enabled,
                onChanged: gemeldet.add,
              ),
              // Etwas anderes, das den Fokus nehmen kann.
              const TextField(key: ValueKey('anderes')),
            ],
          ),
        ),
      ),
    );
    return (controller: controller, gemeldet: gemeldet);
  }

  InputDecoration dekoration(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).decoration!;

  Color tertiaer(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(GermanDateTextField)))
          .colorScheme
          .tertiary;

  testWidgets('ein gültiges Datum: nichts anzumerken, der Hilfetext bleibt', (
    tester,
  ) async {
    await zeige(tester, text: '03.10.2026', helperText: 'Hilfe');

    expect(dekoration(tester).helperText, 'Hilfe');
    expect(dekoration(tester).errorText, isNull);
    expect(find.text(formatSatz), findsNothing);
  });

  testWidgets(
    'ein vorbelegter ungültiger Wert wird sofort angemerkt — als Hinweis',
    (tester) async {
      final (:controller, gemeldet: _) = await zeige(
        tester,
        text: '31.02.2026',
        helperText: 'Hilfe',
      );

      final deko = dekoration(tester);
      expect(deko.helperText, formatSatz);
      expect(deko.helperStyle?.color, tertiaer(tester));
      expect(
        deko.errorText,
        isNull,
        reason: 'Ein errorText läse sich wie eine Sperre.',
      );
      expect(controller.text, '31.02.2026', reason: 'Nichts umgeschrieben.');
    },
  );

  testWidgets('beim Tippen still, nach dem Verlassen der Hinweis', (
    tester,
  ) async {
    final (controller: _, :gemeldet) = await zeige(tester);

    await tester.enterText(find.byType(TextField).first, '03.1');
    await tester.pump();
    expect(find.text(formatSatz), findsNothing);
    expect(gemeldet, ['03.1']);

    await tester.tap(find.byKey(const ValueKey('anderes')));
    await tester.pump();
    expect(find.text(formatSatz), findsOneWidget);
  });

  testWidgets('außerhalb der Grenzen: derselbe Satz wie GermanDateField', (
    tester,
  ) async {
    await zeige(
      tester,
      text: '01.01.2020',
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
    );

    expect(
      dekoration(tester).helperText,
      GermanDateField.meldungen[GermanDateField.rangeError]!(true),
    );
  });

  testWidgets('der Kalender setzt den Text und meldet ihn', (tester) async {
    final (:controller, :gemeldet) = await zeige(tester, text: '03.10.2026');

    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    // Aufgeschlagen beim eingetragenen Datum: Oktober 2026.
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.text, '15.10.2026');
    expect(gemeldet, ['15.10.2026']);
  });

  testWidgets('gesperrt: auch der Kalender', (tester) async {
    await zeige(tester, enabled: false);

    final knopf = tester.widget<IconButton>(find.byType(IconButton));
    expect(knopf.onPressed, isNull);
  });

  group('GermanDateField prüft wie zuvor', () {
    test('pruefe: leer gültig, Format, Bereich', () {
      expect(GermanDateField.pruefe(null), isNull);
      expect(GermanDateField.pruefe('  '), isNull);
      expect(GermanDateField.pruefe(' 3.10.2026 '), isNull);
      expect(GermanDateField.pruefe('31.02.2026'), GermanDateField.formatError);
      expect(
        GermanDateField.pruefe('01.01.2020', firstDate: DateTime(2025)),
        GermanDateField.rangeError,
      );
      expect(
        GermanDateField.pruefe(
          '31.12.2027',
          lastDate: DateTime(2027, 12, 31, 23),
        ),
        isNull,
        reason: 'Nur der Kalendertag der Grenze zählt.',
      );
    });

    test('der Validator meldet dieselben Schlüssel', () {
      Map<String, dynamic> fehler(String wert) => FormControl<String>(
        value: wert,
        validators: [GermanDateField.validator(firstDate: DateTime(2025))],
      ).errors;

      expect(fehler('03.10.2026'), isEmpty);
      expect(fehler('3.10'), {GermanDateField.formatError: true});
      expect(fehler('01.01.2020'), {GermanDateField.rangeError: true});
    });
  });
}
