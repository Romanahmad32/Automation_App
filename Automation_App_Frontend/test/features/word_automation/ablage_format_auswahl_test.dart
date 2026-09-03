import 'package:automation_app/core/theme/presentation/kanzlei_theme.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_format_auswahl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Auswahl „Was abgelegt wird" im Speicherschritt (§6.1) — die Stelle, an
/// der die fehlende Auswahlmarkierung nachweisbar war.
///
/// Der gewählte Zustand trug dort allein die Füllfarbe, und die liegt im
/// Kanzlei-Design bei 1,17:1 gegen den Untergrund. Wer nicht sieht, ob „Word",
/// „PDF" oder „Word + PDF" gewählt ist, legt die falsche Fassung ab — und ohne
/// Word-Fassung bleibt nach dem Aufräumen des Arbeitsordners (§4.6) keine
/// bearbeitbare Datei übrig.
///
/// Geprüft wird die Form, nicht die Farbe: Das Häkchen steht auf genau einer
/// Fassung und wandert mit der Auswahl. Die Farbseite prüft
/// `test/core/theme/auswahl_themes_test.dart`.
void main() {
  Future<void> zeige(WidgetTester tester, {required AblageFormat start}) async {
    var format = start;
    await tester.pumpWidget(
      MaterialApp(
        theme: KanzleiMaterialTheme(ThemeData.light().textTheme).light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AblageFormatAuswahl(
              format: format,
              onChanged: (wert) => setState(() => format = wert),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('genau die gewählte Fassung trägt ein Häkchen', (tester) async {
    await zeige(tester, start: AblageFormat.word);

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('das Häkchen wandert mit der Auswahl', (tester) async {
    await zeige(tester, start: AblageFormat.word);

    await tester.tap(find.text(AblageFormat.pdf.bezeichnung));
    await tester.pumpAndSettle();

    // Immer noch genau eines — und der Hinweis darunter bestätigt, dass die
    // Auswahl wirklich umgesprungen ist.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.textContaining('Das PDF wird dabei'), findsOneWidget);
  });
}
