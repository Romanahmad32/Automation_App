import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_stand_kennzeichen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Kennzeichen in der Übersichtszeile (#104 Stufe 4). Es zeigt genau den
/// Stand, den der Editor beim Speichern mitgeschrieben hat — es rechnet
/// nichts nach.
void main() {
  Future<void> pumpe(WidgetTester tester, GespeicherterStand? stand) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VorlagenStandKennzeichen(stand: stand)),
      ),
    );
  }

  testWidgets('ohne Eintrag: „Noch nicht geprüft", ohne Warnton', (
    tester,
  ) async {
    await pumpe(tester, null);

    expect(find.text('Noch nicht geprüft'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('vollständig: dezent mit Häkchen', (tester) async {
    await pumpe(
      tester,
      const GespeicherterStand(vollstaendig: true, offen: 0, warnungen: false),
    );

    expect(find.text('Vollständig'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('unvollständig: sagt, wie viel offen ist', (tester) async {
    await pumpe(
      tester,
      const GespeicherterStand(vollstaendig: false, offen: 3, warnungen: false),
    );

    expect(find.text('Unvollständig · 3 offen'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('unvollständig ohne Zahl: kein „· 0 offen"', (tester) async {
    // Der Fall einer frischen Kopie: keine Word-Datei, also keine bekannten
    // Platzhalter. „0 offen" neben „Unvollständig" läse sich wie ein
    // Widerspruch.
    await pumpe(tester, GespeicherterStand.ohneDatei);

    expect(find.text('Unvollständig'), findsOneWidget);
    expect(find.textContaining('offen'), findsNothing);
  });
}
