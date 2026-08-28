import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_signatur_bilder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Kacheln, mit denen je Mail entschieden wird, welche Signaturbilder
/// mitgehen (§4.7).
///
/// Beide Tests halten dieselbe Beobachtung fest, von zwei Seiten: Auf jeder
/// ausgewaehlten Kachel stand ein dunkles Quadrat, das aussah, als staende der
/// Zeiger auf allen zugleich. Es war kein Hover-Effekt, sondern der Schleier,
/// den Material ueber einen Avatar legt, wenn es das Haekchen darueber
/// zeichnet. Wer nicht sieht, welche Kachel unter dem Zeiger liegt, weiss bei
/// einer Entscheidung je Mail nicht, was er gerade abwaehlt.
void main() {
  const bilder = [
    SignaturBild(dateiname: 'logo.png', bytes: 20 * 1024),
    SignaturBild(dateiname: 'werbung.gif', bytes: 6 * 1024 * 1024),
  ];

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailSignaturBilder(bilder: bilder, onUmschalten: (_) {}),
        ),
      ),
    );
  }

  testWidgets('der Zeiger auf einem Bild bewegt nur dessen Kachel', (
    tester,
  ) async {
    await zeige(tester);

    final zeiger = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await zeiger.addPointer(location: Offset.zero);
    addTearDown(zeiger.removePointer);
    await tester.pump();

    await zeiger.moveTo(tester.getCenter(find.textContaining('logo.png')));
    await tester.pumpAndSettle();

    // Beide Kacheln sind ausgewaehlt und tragen denselben Tooltip. Erscheint
    // er zweimal, hat die Bewegung auf der einen auch die andere erreicht.
    expect(find.text('Geht mit der Signatur hinaus'), findsOneWidget);
  });

  testWidgets('unter dem Haekchen liegt kein Bildsymbol', (tester) async {
    // Avatar und Haekchen zusammen ergeben den dunklen Schleier. Das Symbol
    // traegt hier ohnehin nichts bei: Jede Kachel dieser Reihe ist ein Bild.
    await zeige(tester);

    expect(find.byIcon(Icons.image_outlined), findsNothing);

    // Das Haekchen bleibt -- es ist die ganze Auskunft „geht mit". Gezeichnet
    // wird es von Material selbst, deshalb steht die Zusage am Widget.
    final kacheln = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(kacheln, hasLength(bilder.length));
    expect(kacheln.every((kachel) => kachel.avatar == null), isTrue);
    expect(kacheln.every((kachel) => kachel.showCheckmark ?? false), isTrue);
  });
}
