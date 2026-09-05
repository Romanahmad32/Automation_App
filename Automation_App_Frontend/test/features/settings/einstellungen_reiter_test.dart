import 'package:automation_app/core/general_widgets/form/speichern_button.dart';
import 'package:automation_app/core/general_widgets/layout/traege_indexed_stack.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
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
/// Bauart hat drei Stellen, an denen sie still kippen kann: Der Wechsel greift
/// nicht mehr, der Knopf scrollt wieder mit dem Inhalt weg, oder die Auswahl
/// wandert beim Reiterwechsel, weil rechts mal ein Knopf steht und mal nicht.
/// Alles drei sieht man einer einzelnen Ansicht nicht an; hier steht es als
/// Test.
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

  /// **Ein** Reiter in einem Fenster bekannter Größe, einmal mit und einmal
  /// ohne Aktion — sonst identisch. Der `DefaultTabController` darum ist
  /// nötig, weil die Zeile ihre Abschnitte nur mit Controller zeichnet.
  Future<void> zeigeReiter(
    WidgetTester tester, {
    required Size fenster,
    required Widget? aktion,
  }) async {
    tester.view.physicalSize = fenster;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: EinstellungenAktionszeile.abschnitte.length,
          child: Scaffold(
            body: EinstellungenReiter(
              aktion: aktion,
              links: const [Text('Inhalt')],
            ),
          ),
        ),
      ),
    );
  }

  /// Die linke obere Ecke jeder Abschnitts-Beschriftung, in der Reihenfolge
  /// der Liste.
  List<Offset> abschnittsEcken(WidgetTester tester) => [
    for (final abschnitt in EinstellungenAktionszeile.abschnitte)
      tester.getTopLeft(find.text(abschnitt.label)),
  ];

  /// Vergleicht die Lage der Abschnitte mit und ohne Speichern-Knopf und gibt
  /// die Ecken des Falls „mit Knopf" zurück, damit der Aufrufer noch prüfen
  /// kann, ob der Wrap in diesem Fenster überhaupt umbricht.
  Future<List<Offset>> eckenMitUndOhneAktion(
    WidgetTester tester,
    Size fenster,
  ) async {
    await zeigeReiter(
      tester,
      fenster: fenster,
      aktion: SpeichernButton(kompakt: true, onSpeichern: () {}),
    );
    final mitAktion = abschnittsEcken(tester);

    await zeigeReiter(tester, fenster: fenster, aktion: null);

    expect(
      abschnittsEcken(tester),
      mitAktion,
      reason:
          'Der Platz für die Aktion bleibt auch ohne Knopf reserviert '
          '(EinstellungenAktionszeile.aktionsbreite). Fällt er weg, wird die '
          'Auswahl links breiter, bricht anders um — und die Chips springen '
          'beim Reiterwechsel, je nachdem ob der Reiter speichert.',
    );

    return mitAktion;
  }

  testWidgets('die Abschnittswahl steht im breiten Fenster mit und ohne '
      'Aktion an derselben Stelle', (tester) async {
    await eckenMitUndOhneAktion(tester, const Size(1400, 900));
  });

  testWidgets('die Abschnittswahl steht auch im umgebrochenen Fenster mit '
      'und ohne Aktion an derselben Stelle', (tester) async {
    final ecken = await eckenMitUndOhneAktion(tester, const Size(640, 900));

    expect(
      ecken.map((ecke) => ecke.dy).toSet().length,
      greaterThanOrEqualTo(2),
      reason:
          'Genau der Umbruch ist hier die Aussage: Passt die Auswahl in eine '
          'Zeile, hätte auch die alte Fassung bestanden und der Test '
          'bewachte nichts mehr.',
    );
  });

  testWidgets('ein kompakter Speichern-Knopf passt in den reservierten Platz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        // Mit dem App-Theme messen, nicht mit dem Material-Standard: Polsterung
        // und Schriftgröße des Knopfes kommen aus dessen `filledButtonTheme`.
        // Die Schrift-Skala wie in `auswahl_themes_test.dart` aus
        // `ThemeData.light()` — `createTextTheme` bräuchte einen Context und
        // holte Google-Fonts.
        theme: MaterialTheme(ThemeData.light().textTheme).light(),
        home: Scaffold(
          body: Center(
            child: SpeichernButton(kompakt: true, onSpeichern: () {}),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SpeichernButton)).width,
      lessThanOrEqualTo(EinstellungenAktionszeile.aktionsbreite),
      reason:
          'Sonst veraltet die Konstante stillschweigend, sobald sich Theme, '
          'Schriftgröße oder Beschriftung ändern: Der Knopf liefe über den '
          'reservierten Platz hinaus und schöbe die Auswahl zusammen.',
    );
  });

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
