import 'package:automation_app/features/email_versand/presentation/widgets/signatur_ansicht.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_html_ansicht.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Links in gerendertem HTML tragen `colorScheme.primary` (Issue #185); eine
/// Farbe, die das HTML selbst setzt, bleibt.
void main() {
  const eigeneFarbe = Color(0xFF00AA00);
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB00020)),
  );

  /// Die Farbe des ersten Textstücks, das [text] enthält.
  Color? farbeVon(WidgetTester tester, String text) {
    Color? gefunden;
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan && (span.text ?? '').contains(text)) {
          gefunden ??= span.style?.color;
        }
        return true;
      });
    }
    return gefunden;
  }

  Future<void> zeige(WidgetTester tester, Widget kind) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: kind),
    ),
  );

  const html =
      '<p><a href="https://beispiel.de">Verweis</a> '
      '<a href="https://beispiel.de" style="color: #00AA00">Eigen</a></p>';

  testWidgets('Signatur: Link trägt primary, Inline-Farbe bleibt', (
    tester,
  ) async {
    await zeige(tester, const SignaturAnsicht(html: html));

    expect(farbeVon(tester, 'Verweis'), theme.colorScheme.primary);
    expect(farbeVon(tester, 'Eigen'), eigeneFarbe);
  });

  testWidgets('Anker ohne href (Outlook) behält die Textfarbe', (tester) async {
    await zeige(
      tester,
      const SignaturAnsicht(html: '<p><a name="x">Anker</a> Fliesstext</p>'),
    );

    expect(farbeVon(tester, 'Anker'), isNot(theme.colorScheme.primary));
  });

  testWidgets('Posteingang: Link trägt primary, Inline-Farbe bleibt', (
    tester,
  ) async {
    await zeige(tester, const PosteingangHtmlAnsicht(html: html));

    expect(farbeVon(tester, 'Verweis'), theme.colorScheme.primary);
    expect(farbeVon(tester, 'Eigen'), eigeneFarbe);
  });
}
