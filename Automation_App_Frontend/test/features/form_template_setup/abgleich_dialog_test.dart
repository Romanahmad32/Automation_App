import 'package:automation_app/features/form_template_setup/presentation/widgets/abgleich_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Abgleich nach einem Dateiwechsel (#104, Stufe 3b): Welche Felder gehen
/// mit dem weggefallenen Platzhalter?
///
/// Alles ist vorausgewählt, aber nichts geht ungefragt weg — die beiden
/// Knöpfe stehen für genau diese zwei Antworten.
void main() {
  late List<String>? entfernt;

  setUp(() => entfernt = null);

  /// Baut eine Seite mit einem Knopf, der den Dialog mit einem echten
  /// [BuildContext] öffnet — anders lässt sich `showDialog` nicht auslösen.
  Future<void> zeige(
    WidgetTester tester, {
    required List<String> felder,
    String dateiname = 'HGn.docx',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                entfernt = await zeigeAbgleichDialog(
                  context,
                  dateiname: dateiname,
                  felder: felder,
                );
              },
              child: const Text('los'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
  }

  testWidgets('der Dialog nennt die Datei und listet jedes Feld', (
    tester,
  ) async {
    await zeige(tester, felder: const ['Frist', 'Zeichen']);

    expect(find.text('Datei neu eingelesen'), findsOneWidget);
    expect(
      find.textContaining('kommen in HGn.docx nicht mehr vor'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Frist'), findsOneWidget);
    expect(find.text('Zeichen'), findsOneWidget);
  });

  testWidgets('vorausgewählt ist alles — „Ausgewählte entfernen" liefert '
      'jeden Namen', (tester) async {
    await zeige(tester, felder: const ['Frist', 'Zeichen']);

    await tester.tap(find.text('Ausgewählte entfernen'));
    await tester.pumpAndSettle();

    expect(entfernt, ['Frist', 'Zeichen']);
  });

  testWidgets('ein abgewählter Haken bleibt — zurück kommen nur die '
      'gehakten', (tester) async {
    await zeige(tester, felder: const ['Frist', 'Zeichen', 'Unfalltag']);

    await tester.tap(find.text('Zeichen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ausgewählte entfernen'));
    await tester.pumpAndSettle();

    // In der Reihenfolge der Felder, nicht in der des Anklickens.
    expect(entfernt, ['Frist', 'Unfalltag']);
  });

  testWidgets('„Behalten" liefert nichts', (tester) async {
    await zeige(tester, felder: const ['Frist']);

    await tester.tap(find.text('Behalten'));
    await tester.pumpAndSettle();

    expect(entfernt, isEmpty);
  });

  testWidgets('ohne jeden Haken ist der Entfernen-Knopf aus', (tester) async {
    // Er täte dann dasselbe wie „Behalten" und behauptete das Gegenteil.
    await zeige(tester, felder: const ['Frist']);

    await tester.tap(find.text('Frist'));
    await tester.pumpAndSettle();

    final knopf = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ausgewählte entfernen'),
    );
    expect(knopf.onPressed, isNull);
  });

  testWidgets('das Wegtippen neben den Dialog behält alles', (tester) async {
    await zeige(tester, felder: const ['Frist']);

    // Neben den Dialog: die Barriere oben links.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(entfernt, isEmpty);
  });

  testWidgets('ohne Kandidaten wird nicht gefragt', (tester) async {
    // Kein Dialog vor jedem Dateiwechsel — nur wenn wirklich etwas
    // weggefallen ist.
    await zeige(tester, felder: const []);

    expect(find.byType(AlertDialog), findsNothing);
    expect(entfernt, isEmpty);
  });
}
