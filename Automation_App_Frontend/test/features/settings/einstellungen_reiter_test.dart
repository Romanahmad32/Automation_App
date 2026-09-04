import 'package:automation_app/core/general_widgets/layout/traege_indexed_stack.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_aktionszeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_reiter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Kopfzeile der Einstellungen trägt zwei Dinge, die vorher woanders
/// standen: die Abschnittswahl (früher eine `TabBar`) und den Speichern-Knopf
/// (früher am Ende des Formulars).
///
/// Beides ist über den Aufbau verbunden — jeder Reiter zeichnet die Zeile
/// selbst, der Abschnitt kommt aus dem `DefaultTabController` darüber. Diese
/// Bauart hat zwei Stellen, an denen sie still kippen kann: Der Wechsel greift
/// nicht mehr, oder der Knopf scrollt wieder mit dem Inhalt weg. Beides sieht
/// man einer Ansicht nicht an; hier steht es als Test.
void main() {
  /// Sechs Reiter in einem Stack, wie sie die Einstellungsseite aufhängt.
  Future<void> zeigeSeite(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: EinstellungenAktionszeile.abschnitte.length,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => TraegeIndexedStack(
                    index: controller.index,
                    children: [
                      for (
                        var i = 0;
                        i < EinstellungenAktionszeile.abschnitte.length;
                        i++
                      )
                        EinstellungenReiter(links: [Text('Inhalt $i')]),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ein Klick auf einen Abschnitt wechselt den Reiter', (
    tester,
  ) async {
    await zeigeSeite(tester);

    expect(find.text('Inhalt 0'), findsOneWidget);
    expect(
      find.text('Inhalt 2'),
      findsNothing,
      reason:
          'Der Stack baut einen Reiter erst, wenn er zum ersten Mal gezeigt '
          'wird — sonst laufen beim Öffnen der Seite alle sechs los.',
    );

    await tester.tap(find.text('E-Mail'));
    await tester.pumpAndSettle();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
    expect(find.text('Inhalt 2'), findsOneWidget);
  });

  testWidgets('der Speichern-Knopf bleibt beim Scrollen stehen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EinstellungenReiter(
            aktion: Text('Speichern'),
            links: [
              SizedBox(height: 2000, child: Text('sehr langes Formular')),
            ],
          ),
        ),
      ),
    );

    final knopfVorher = tester.getTopLeft(find.text('Speichern'));
    final inhaltVorher = tester.getTopLeft(find.text('sehr langes Formular'));

    // Am Scrollbereich ziehen, nicht am Inhalt: Dessen Mitte liegt bei 2000 px
    // Höhe außerhalb des Fensters, der Griff ginge ins Leere.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('sehr langes Formular')).dy,
      lessThan(inhaltVorher.dy),
      reason: 'Ohne tatsächliche Bewegung sagt der Vergleich darunter nichts.',
    );
    expect(
      tester.getTopLeft(find.text('Speichern')),
      knopfVorher,
      reason:
          'Der Knopf steht in der Kopfzeile über dem Scrollbereich. Rutscht '
          'er hinein, ist der Gewinn der Umstellung wieder weg: Wer oben ein '
          'Feld ändert, müsste zum Speichern wieder ans Ende scrollen.',
    );
  });

  testWidgets('bleibt ohne DefaultTabController bedienbar', (tester) async {
    // Die Widgettests der einzelnen Reiter hängen sie ohne Seite darum auf.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EinstellungenReiter(
            aktion: Text('Speichern'),
            links: [Text('Inhalt')],
          ),
        ),
      ),
    );

    expect(find.text('Inhalt'), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);
    expect(
      find.text('Kanzlei'),
      findsNothing,
      reason: 'Ohne Controller gibt es keinen Abschnitt zum Wechseln.',
    );
  });
}
