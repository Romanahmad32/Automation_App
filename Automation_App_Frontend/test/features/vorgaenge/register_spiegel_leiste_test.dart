import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_spiegel_leiste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// §6.2 „Word sofort, PDF nachgezogen": Solange eine PDF-Fassung noch
/// entsteht, sagt die Leiste das — und nicht, dass ein PDF fehle.
void main() {
  Future<void> zeigeLeiste(
    WidgetTester tester,
    RegisterSpiegelErgebnis stand,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RegisterSpiegelLeiste(stand: stand)),
      ),
    );
  }

  testWidgets('pdfLaeuft sagt, dass das PDF noch entsteht', (tester) async {
    await zeigeLeiste(
      tester,
      const RegisterSpiegelErgebnis(
        geschrieben: true,
        docxPfad: r'C:\OneDrive\Register.docx',
        pdfLaeuft: true,
      ),
    );

    expect(find.textContaining('das PDF entsteht noch'), findsOneWidget);
    expect(find.textContaining('fehlt'), findsNothing);
  });

  /// Verteidigend: Der Vertrag sagt, `pdfFehler` stehe nie neben
  /// `pdfLaeuft: true` — trotzdem darf die Leiste beides zusammen nie zeigen.
  testWidgets(
    'pdfLaeuft verdrängt einen (eigentlich ausgeschlossenen) pdfFehler',
    (tester) async {
      await zeigeLeiste(
        tester,
        const RegisterSpiegelErgebnis(
          geschrieben: true,
          pdfLaeuft: true,
          pdfFehler: 'Word ist nicht installiert.',
        ),
      );

      expect(find.textContaining('das PDF entsteht noch'), findsOneWidget);
      expect(find.textContaining('Word ist nicht installiert'), findsNothing);
    },
  );

  testWidgets('ohne pdfLaeuft steht der Klartext aus pdfFehler da', (
    tester,
  ) async {
    await zeigeLeiste(
      tester,
      const RegisterSpiegelErgebnis(
        geschrieben: true,
        pdfFehler: 'Word ist nicht installiert.',
      ),
    );

    expect(find.textContaining('Word ist nicht installiert'), findsOneWidget);
    expect(find.textContaining('das PDF entsteht noch'), findsNothing);
  });

  testWidgets('ohne pdfLaeuft und ohne pdfFehler steht keine PDF-Zeile da', (
    tester,
  ) async {
    await zeigeLeiste(
      tester,
      const RegisterSpiegelErgebnis(
        geschrieben: true,
        docxPfad: r'C:\OneDrive\Register.docx',
      ),
    );

    expect(find.textContaining('PDF'), findsNothing);
  });
}
