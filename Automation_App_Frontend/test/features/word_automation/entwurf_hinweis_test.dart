import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/entwurf_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Leiste ist die ganze Sichtbarkeit des Entwurfs: Sie sagt, **wann** der
/// Stand entstand, und stellt beide Wege nebeneinander. Ein Stand ohne Zeitpunkt
/// ist eine Zumutung — „Weiterarbeiten" heißt dann, auf gut Glück Werte in ein
/// Schreiben zu holen.
void main() {
  final entwurf = VorgangEntwurf(
    gespeichertAm: DateTime(2026, 8, 30, 14, 32),
    feldWerte: const {'Versicherer': 'HUK-COBURG'},
  );

  test('von heute reicht die Uhrzeit', () {
    expect(
      EntwurfHinweis.beschriftung(
        DateTime(2026, 8, 30, 14, 32),
        DateTime(2026, 8, 30, 18, 5),
      ),
      'Angefangener Stand von 14:32 Uhr',
    );
  });

  test('älteres trägt sein Datum', () {
    expect(
      EntwurfHinweis.beschriftung(
        DateTime(2026, 8, 30, 9, 5),
        DateTime(2026, 9, 14, 10, 0),
      ),
      'Angefangener Stand vom 30.08.2026, 09:05 Uhr',
    );
  });

  testWidgets('bietet beide Wege an', (tester) async {
    var weiter = 0;
    var verworfen = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntwurfHinweis(
            entwurf: entwurf,
            onWeiterarbeiten: () => weiter++,
            onVerwerfen: () => verworfen++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Weiterarbeiten'));
    await tester.tap(find.text('Verwerfen'));

    expect(weiter, 1);
    expect(verworfen, 1);
  });
}
