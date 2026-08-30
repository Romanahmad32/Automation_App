import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/feld_einstellung_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Dialog aus Teil 3 von #37. Er entscheidet nichts, er liefert ab — aber
/// er lässt nichts durch, was die Vorlage später unbrauchbar machte: keinen
/// leeren Namen, keinen, den der Dienst beim Erzeugen mit 400 ablehnt, und
/// keinen, den es in der Vorlage schon gibt.
void main() {
  const feld = FieldData(
    order: 0,
    label: 'Versicherer',
    required: true,
    inputType: InputType.text,
  );

  group('beanstandung', () {
    test('ein leerer Name wird abgelehnt', () {
      expect(FeldEinstellungDialog.beanstandung('   ', const []), isNotNull);
    });

    test('Umlaute, Ziffern, Bindestrich und Unterstrich sind erlaubt', () {
      expect(
        FeldEinstellungDialog.beanstandung('Größe_2 - Gegner', const []),
        isNull,
      );
    });

    /// Der Dienst prüft `^[\p{L}\p{N} _-]+$` erst beim Erzeugen. Ein Punkt im
    /// Namen fiele sonst einen Arbeitsschritt später auf — mit HTTP 400 und
    /// wieder einer Vorlage, die bearbeitet werden muss.
    test('ein Punkt wird abgelehnt, wie der Dienst es täte', () {
      expect(
        FeldEinstellungDialog.beanstandung('Versicherungsschein-Nr.', const []),
        contains('Erlaubt sind'),
      );
    });

    test('ein schon belegter Name wird abgelehnt, auch anders geschrieben', () {
      expect(
        FeldEinstellungDialog.beanstandung('kennzeichen', const [
          'Kennzeichen',
        ]),
        contains('gibt es in der Vorlage schon'),
      );
    });

    test('der eigene Name bleibt erlaubt', () {
      // Der Aufrufer übergibt nur die *übrigen* Felder — sonst beanstandete der
      // Dialog jede Änderung, die den Namen unangetastet lässt.
      expect(
        FeldEinstellungDialog.beanstandung('Versicherer', const [
          'Kennzeichen',
        ]),
        isNull,
      );
    });
  });

  /// Was der Dialog beim Schließen geliefert hat. Steht außerhalb der Tests,
  /// weil es erst *nach* dem Schließen ankommt — [oeffne] setzt es zurück.
  final geliefert = <FieldData?>[];

  Future<void> oeffne(
    WidgetTester tester, {
    List<String> belegteNamen = const [],
  }) async {
    geliefert.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                geliefert.add(
                  await FeldEinstellungDialog.zeige(
                    context,
                    feld: feld,
                    belegteNamen: belegteNamen,
                  ),
                );
              },
              child: const Text('öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets('„Vorlage speichern" liefert das geänderte Feld', (tester) async {
    await oeffne(tester);

    await tester.enterText(find.byType(TextField).first, 'Versicherung');
    await tester.tap(find.text('Erforderlich'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorlage speichern'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final neu = geliefert.single;
    expect(neu?.label, 'Versicherung');
    expect(neu?.required, isFalse);
    // Was der Dialog nicht anfasst, kommt unverändert zurück.
    expect(neu?.inputType, InputType.text);
    expect(neu?.order, 0);
  });

  testWidgets('ein leerer Name schließt den Dialog nicht', (tester) async {
    await oeffne(tester);

    await tester.enterText(find.byType(TextField).first, '  ');
    await tester.tap(find.text('Vorlage speichern'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Der Feldname darf nicht leer sein.'), findsOneWidget);
  });

  testWidgets('die Beanstandung verschwindet beim nächsten Tippen', (
    tester,
  ) async {
    await oeffne(tester);
    await tester.enterText(find.byType(TextField).first, '  ');
    await tester.tap(find.text('Vorlage speichern'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Versicherung');
    await tester.pumpAndSettle();

    expect(find.text('Der Feldname darf nicht leer sein.'), findsNothing);
  });

  testWidgets('der Dialog zeigt die Einstellung des Felds', (tester) async {
    await oeffne(tester);

    expect(find.text('Versicherer'), findsOneWidget);
    expect(find.text(InputType.text.displayName), findsOneWidget);
    expect(find.text(FeldDatenquelle.keine.displayName), findsOneWidget);
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox)).value,
      isTrue,
      reason: 'das Feld ist ein Pflichtfeld',
    );
  });

  testWidgets('„Abbrechen" ändert nichts', (tester) async {
    await oeffne(tester);

    await tester.enterText(find.byType(TextField).first, 'Versicherung');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(geliefert.single, isNull);
  });
}
