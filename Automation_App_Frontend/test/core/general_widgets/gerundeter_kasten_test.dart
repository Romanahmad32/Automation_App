import 'package:automation_app/core/general_widgets/gerundeter_kasten.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Kasten ersetzt einen `Container` mit `BoxDecoration`, und zwar wegen
/// zweier Eigenschaften, die man beim nächsten Umbau leicht wieder verliert:
/// Er ist selbst die `Material`-Fläche, auf die Antippbares seinen Kringel
/// zeichnet, und er schneidet sie an seinen runden Ecken ab. Beides sieht man
/// nur im laufenden Bild — deshalb steht es hier.
void main() {
  testWidgets('ist die Material-Fläche für alles Antippbare darin und '
      'schneidet an seinen Ecken ab', (tester) async {
    late BuildContext innen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GerundeterKasten(
            farbe: const Color(0xFFEEF2FF),
            randfarbe: const Color(0xFF6366F1),
            rundung: 12,
            child: Builder(
              builder: (context) {
                innen = context;
                return const SizedBox(height: 40);
              },
            ),
          ),
        ),
      ),
    );

    // Nicht irgendein Material, sondern der Kasten selbst: Ein durchsichtiges
    // `Material` als Zwischenschicht bestünde die erste Zusicherung auch,
    // schnitte den Kringel aber nicht ab — genau der Fehler, aus dem dieser
    // Baustein entstanden ist.
    final flaeche = innen.findAncestorWidgetOfExactType<Material>()!;
    expect(flaeche.color, const Color(0xFFEEF2FF));
    expect(flaeche.clipBehavior, Clip.antiAlias);
    expect(
      flaeche.shape,
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF6366F1)),
      ),
    );
  });

  testWidgets('lässt die Schrift darin erben, statt sie auf bodyMedium '
      'zurückzusetzen', (tester) async {
    const vorgabe = TextStyle(fontSize: 27, color: Color(0xFF111827));
    late TextStyle innen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: vorgabe,
            child: GerundeterKasten(
              farbe: const Color(0xFFEEF2FF),
              child: Builder(
                builder: (context) {
                  innen = DefaultTextStyle.of(context).style;
                  return const SizedBox(height: 40);
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Ein `Material` setzt sonst einen eigenen `DefaultTextStyle` — jeder
    // `Text` ohne eigenes `style` darin spränge auf `bodyMedium` und
    // übergänge damit die vom Anwalt gewählte Schriftstufe.
    expect(innen.fontSize, vorgabe.fontSize);
    expect(innen.color, vorgabe.color);
  });
}
