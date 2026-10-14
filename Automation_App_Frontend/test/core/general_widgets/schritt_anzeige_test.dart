import 'package:automation_app/core/general_widgets/schritt_anzeige.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Die Schrittanzeige des Dialogs „App aktualisieren“ (#196): erledigte
/// Schritte mit Haken, der laufende gefüllt, die übrigen mit Nummer.
void main() {
  Future<void> zeige(WidgetTester tester, SchrittAnzeige anzeige) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 420, child: anzeige)),
        ),
      );

  testWidgets('vor dem Start: drei Nummern, kein Haken', (tester) async {
    await zeige(
      tester,
      const SchrittAnzeige(
        schritte: ['Herunterladen', 'Neu starten', 'Fertig'],
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('bereit: Herunterladen erledigt, Neu starten läuft', (
    tester,
  ) async {
    await zeige(
      tester,
      const SchrittAnzeige(
        schritte: ['Herunterladen', 'Neu starten', 'Fertig'],
        erledigt: 1,
        aktiv: 1,
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('1'), findsNothing);
    final laufend = tester.widget<Text>(find.text('Neu starten'));
    expect(laufend.style?.fontWeight, FontWeight.w600);
    final offen = tester.widget<Text>(find.text('Fertig'));
    expect(offen.style?.fontWeight, isNot(FontWeight.w600));
  });
}
