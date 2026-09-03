import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/zeichen_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was tatsächlich auf dem Bildschirm steht.
///
/// `zeichen_anzeige_test.dart` verbietet die *falsche* Schreibweise, sagt aber
/// nichts darüber, ob die richtige auch das Richtige liefert — beides zusammen
/// ergibt die Regel. Und der Rückfall („Referenz nicht zerlegbar") ist der
/// Fall, in dem Zeichen und Referenz zusammenfallen: Er entscheidet, ob die
/// Kachel eine Nebenzeile bekommt oder dieselbe Zeichenkette doppelt zeigt.
void main() {
  Vorgang zerlegt() => Vorgang.ausAnfrage(
    referenz: '216/26 C03_EU-FE 1111',
    angefragtAm: DateTime(2026, 6, 20),
  );

  /// Eine Referenz, die dem Schema nicht folgt — von Hand eingetragen.
  Vorgang freitext() => Vorgang.ausAnfrage(
    referenz: 'Altfall Mustermann',
    angefragtAm: DateTime(2026, 6, 20),
  );

  Future<void> zeige(WidgetTester tester, Widget kind) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: kind)));

  testWidgets('zeigt das Zeichen, nicht die volle Referenz', (tester) async {
    await zeige(tester, ZeichenText(zerlegt()));

    expect(find.text('216/26 C03'), findsOneWidget);
    expect(find.text('216/26 C03_EU-FE 1111'), findsNothing);
  });

  testWidgets('ohne zerlegbare Referenz zeigt es sie unverkürzt', (
    tester,
  ) async {
    await zeige(tester, ZeichenText(freitext()));

    // Lieber der ganze Schlüssel als gar keiner: Ein leeres Feld wäre hier
    // schlimmer als ein technisch aussehender Bezeichner.
    expect(find.text('Altfall Mustermann'), findsOneWidget);
  });

  testWidgets('ausReferenz kommt ohne Vorgang zum selben Ergebnis', (
    tester,
  ) async {
    await zeige(tester, const ZeichenText.ausReferenz('216/26 C03_EU-FE 1111'));

    expect(find.text('216/26 C03'), findsOneWidget);
  });

  group('referenzZusatz — die Nebenzeile unter dem Zeichen', () {
    test('trägt die volle Referenz, wenn sie mehr sagt', () {
      expect(zerlegt().referenzZusatz, '216/26 C03_EU-FE 1111');
    });

    test('entfällt, wenn Zeichen und Referenz dasselbe sind', () {
      // Sonst stünde „Altfall Mustermann" zweimal untereinander auf der
      // Kachel — einmal als Zeichen, einmal als Nebenzeile.
      expect(freitext().referenzZusatz, isNull);
    });
  });
}
