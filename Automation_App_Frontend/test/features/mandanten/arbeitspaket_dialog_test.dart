import 'package:automation_app/features/mandanten/presentation/widgets/arbeitspaket_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Öffnet den Dialog und legt das Ergebnis in [ergebnis] ab — so wie der
/// Knopf ihn aufruft.
Widget seite(int offen, List<int?> ergebnis) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final wert = await showDialog<int>(
            context: context,
            builder: (_) => ArbeitspaketDialog(offen: offen),
          );
          ergebnis.add(wert);
        },
        child: const Text('öffnen'),
      ),
    ),
  ),
);

Future<void> oeffne(WidgetTester tester, int offen, List<int?> ergebnis) async {
  await tester.pumpWidget(seite(offen, ergebnis));
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('schlägt 200 vor und nennt die Zahl der offenen Ordner', (
    tester,
  ) async {
    final ergebnis = <int?>[];
    await oeffne(tester, 857, ergebnis);

    expect(find.text('200'), findsOneWidget);
    expect(find.text('857 Ordner sind noch offen'), findsOneWidget);
  });

  testWidgets('gibt die gewählte Größe zurück', (tester) async {
    final ergebnis = <int?>[];
    await oeffne(tester, 857, ergebnis);

    await tester.enterText(find.byType(TextField), '50');
    await tester.pump();
    await tester.tap(find.text('Datei speichern'));
    await tester.pumpAndSettle();

    expect(ergebnis.single, 50);
  });

  testWidgets('Abbrechen holt nichts', (tester) async {
    final ergebnis = <int?>[];
    await oeffne(tester, 857, ergebnis);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(ergebnis.single, isNull);
  });

  // Ohne Zahl gäbe es kein Paket — der Knopf darf dann nicht führen.
  testWidgets('ohne Zahl lässt sich nicht speichern', (tester) async {
    final ergebnis = <int?>[];
    await oeffne(tester, 857, ergebnis);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    final knopf = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(knopf.onPressed, isNull);
  });
}
