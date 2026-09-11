import 'package:automation_app/features/mandanten/presentation/widgets/kennzeichen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Am Mandanten hängen 0..n Kennzeichen, und sie werden später verglichen —
/// gegen die Zentralruf-Antwort, gegen das Feld im Anspruchsschreiben.
/// Aufgenommen wird jeder Wert, **wie er getippt wurde** (§4.2, geändert am
/// 11.09.2026 — bis dahin der normalisierte). Als Dublette zählt er trotzdem
/// in jeder Schreibweise: Stünde `hg-e1427` neben `HG-E 1427` in derselben
/// Liste, wäre derselbe Wagen zweimal hinterlegt.
void main() {
  /// Die zuletzt gemeldete Liste — der Wert, der beim Speichern am Mandanten
  /// landet. Absichtlich nicht die Chips: Die zeigen nur, was gemeldet wurde.
  late List<String> gemeldet;

  Future<void> zeigeEditor(
    WidgetTester tester, {
    List<String> vorhanden = const [],
  }) async {
    gemeldet = List.of(vorhanden);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KennzeichenEditor(
            initialKennzeichen: vorhanden,
            onChanged: (werte) => gemeldet = werte,
          ),
        ),
      ),
    );
  }

  Future<void> fuegeHinzu(WidgetTester tester, String eingabe) async {
    await tester.enterText(find.byType(TextField), eingabe);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
  }

  testWidgets('nimmt eine Schreibvariante auf, wie sie getippt wurde', (
    tester,
  ) async {
    await zeigeEditor(tester);

    await fuegeHinzu(tester, 'hg-e 1427');

    expect(gemeldet, ['hg-e 1427']);
    expect(find.widgetWithText(Chip, 'hg-e 1427'), findsOneWidget);
  });

  testWidgets(
    'erkennt dasselbe Kennzeichen in anderer Schreibweise als Dublette',
    (tester) async {
      await zeigeEditor(tester);

      await fuegeHinzu(tester, 'hg-e 1427');
      await fuegeHinzu(tester, 'HG-E 1427');

      expect(
        find.text('Dieses Kennzeichen ist bereits hinterlegt'),
        findsOneWidget,
      );
      expect(gemeldet, ['hg-e 1427']);
      expect(find.byType(Chip), findsOneWidget);
    },
  );

  /// Dieselbe Auskunft wie im Formular — und dieselbe Zurückhaltung: Bei einem
  /// Wert, bei dem offen ist, wo das Unterscheidungszeichen endet, **rät die
  /// App nicht**. Aufgenommen wird er trotzdem, und zwar wie getippt: Ein
  /// abgelehnter Wert hälfe niemandem, ein geratener hinge dauerhaft am
  /// Mandanten und träfe später die Zuordnung einer Zentralruf-Antwort (#130).
  testWidgets('nimmt ein mehrdeutiges Kennzeichen ungeteilt auf', (
    tester,
  ) async {
    await zeigeEditor(tester);
    await fuegeHinzu(tester, 'hge1427');

    expect(gemeldet, ['hge1427']);
    expect(find.widgetWithText(Chip, 'hge1427'), findsOneWidget);
  });

  /// Der Hinweis dazu steht am Feld, solange der Wert dort steht — er hält
  /// nichts auf, er sagt nur, was ein Bindestrich klären würde.
  testWidgets('merkt einen mehrdeutigen Wert beim Tippen an', (tester) async {
    await zeigeEditor(tester);

    await tester.enterText(find.byType(TextField), 'hge1427');
    await tester.pump();

    expect(
      find.text('Mehrdeutig, bitte mit Bindestrich: HG-E 1427 oder H-GE 1427'),
      findsOneWidget,
    );
  });

  /// Der Fall aus der Kanzlei: Ein Roller trägt ein Versicherungskennzeichen.
  /// Welche Fahrzeuge der Mandant fährt, entscheidet nicht die App (§4.1).
  testWidgets('nimmt ein Versicherungskennzeichen auf', (tester) async {
    await zeigeEditor(tester);
    await fuegeHinzu(tester, '123 ABC');

    expect(gemeldet, ['123 ABC']);
    expect(find.widgetWithText(Chip, '123 ABC'), findsOneWidget);
  });

  testWidgets('zeigt die hinterlegten Kennzeichen als Chips', (tester) async {
    await zeigeEditor(tester, vorhanden: const ['HG-E 1427', 'F-AB 12']);

    expect(find.byType(Chip), findsNWidgets(2));
  });
}
