import 'package:automation_app/core/general_widgets/layout/karten_spalten.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Umbruchregel der Einstellungsseite, festgehalten an den beiden Fällen,
/// die sie kaputt machen würden.
///
/// Sie ist ein Zahlenwert in einem `LayoutBuilder` — die Art Code, die
/// niemandem auffällt, wenn sie kippt: Auf dem Entwicklerschirm sieht immer
/// eine der beiden Fassungen richtig aus. Gemeldet würde es erst aus der
/// Kanzlei („die Seite ist plötzlich schmal"), und dann sucht man in sechs
/// Ansichten statt an einer Stelle.
void main() {
  /// Hängt die Spalten in ein Fenster bekannter Breite. Die Höhe ist
  /// großzügig, damit nichts überläuft und ein Überlauf-Fehler die eigentliche
  /// Aussage verdeckt.
  Future<void> zeige(WidgetTester tester, double breite) async {
    tester.view.physicalSize = Size(breite, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KartenSpalten(
            links: const [SizedBox(height: 40, child: Text('links'))],
            rechts: const [SizedBox(height: 40, child: Text('rechts'))],
          ),
        ),
      ),
    );
  }

  double x(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dx;

  double y(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('legt die beiden Hälften ab der Grenze nebeneinander', (
    tester,
  ) async {
    await zeige(tester, KartenSpalten.zweiSpaltenAb + 200);

    expect(
      y(tester, 'rechts'),
      y(tester, 'links'),
      reason: 'Zwei Spalten fangen auf derselben Höhe an.',
    );
    expect(x(tester, 'rechts'), greaterThan(x(tester, 'links')));
  });

  testWidgets('stapelt sie darunter, links zuerst', (tester) async {
    await zeige(tester, KartenSpalten.zweiSpaltenAb - 200);

    expect(
      y(tester, 'rechts'),
      greaterThan(y(tester, 'links')),
      reason:
          'Einspaltig steht „rechts" unter „links" — wer die Reihenfolge '
          'dreht, dreht auf schmalen Fenstern die Lesereihenfolge der '
          'ganzen Seite.',
    );
    expect(x(tester, 'rechts'), x(tester, 'links'));
  });

  testWidgets('bleibt ohne rechte Hälfte auch auf einem breiten Schirm '
      'einspaltig und gedeckelt', (tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KartenSpalten(
            links: [SizedBox(height: 40, child: Text('allein'))],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.text('allein')).width,
      lessThanOrEqualTo(KartenSpalten.maxBreiteEinspaltig),
      reason:
          'Ohne Deckel liefe eine einzelne Karte über die volle Breite des '
          'Monitors — die Beschriftung stünde meterweit von ihrem Feld.',
    );
  });
}
