import 'dart:async';

import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reicht den `BuildContext` der Testseite nach außen, damit ein Test
/// Rückmeldungen genauso auslösen kann wie eine Seite: mit einem Kontext aus
/// dem Baum unter `MaterialApp`.
class KontextHalter extends StatelessWidget {
  const KontextHalter({super.key, required this.merken});

  final void Function(BuildContext context) merken;

  @override
  Widget build(BuildContext context) {
    merken(context);
    return const SizedBox.shrink();
  }
}

/// Der Testbaum: eine gewöhnliche Seite mit einem `Scaffold` — so wie die App
/// gebaut ist, mit genau einem `Scaffold` in der Shell.
Widget probe(void Function(BuildContext context) merken) => MaterialApp(
  home: Scaffold(body: KontextHalter(merken: merken)),
);

/// Prüft die drei Zusagen, wegen derer es [Rueckmeldung] überhaupt gibt
/// (Issue #56): Die Meldung liegt **über** der Dialogbarriere und bleibt dort
/// bedienbar; ein Fehler verschwindet **nicht** von selbst, weil in drei
/// Sekunden niemand liest, was zu tun ist; und mehrere Meldungen stapeln sich,
/// statt einander zu verdrängen.
///
/// Dazu die Robustheit, an der die bisherige Lösung scheiterte: ein Handle, der
/// vor einem `await` gefasst wurde, und ein Baum, der unter einer stehenden
/// Meldung weggezogen wird.
///
/// `pumpAndSettle` wird bewusst gemieden, solange eine Meldung mit Timer steht:
/// Es pumpt Bild um Bild und würde die Meldung nebenbei ablaufen lassen. Wo auf
/// Zeit gewartet wird, steht ein `pump(Duration)`.
void main() {
  testWidgets('Erfolg erscheint und ist nach drei Sekunden wieder weg', (
    tester,
  ) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeErfolg(kontext, 'Tabellenfarbe gespeichert.');
    await tester.pump();

    expect(find.text('Tabellenfarbe gespeichert.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Tabellenfarbe gespeichert.'), findsNothing);
  });

  testWidgets('Fehler bleibt stehen, bis er geschlossen wird', (tester) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeFehler(kontext, 'Speichern fehlgeschlagen.');
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Speichern fehlgeschlagen.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Speichern fehlgeschlagen.'), findsNothing);
  });

  testWidgets('Meldungen stapeln sich, die neueste steht oben', (tester) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeFehler(kontext, 'Erste Meldung.');
    await tester.pump();
    Rueckmeldung.zeigeFehler(kontext, 'Zweite Meldung.');
    await tester.pump();

    expect(find.text('Erste Meldung.'), findsOneWidget);
    expect(find.text('Zweite Meldung.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Zweite Meldung.')).dy,
      lessThan(tester.getTopLeft(find.text('Erste Meldung.')).dy),
      reason: 'Die neueste Meldung gehoert nach oben.',
    );
  });

  testWidgets('die vierte Meldung verdrängt die älteste', (tester) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    for (final text in ['Erste.', 'Zweite.', 'Dritte.', 'Vierte.']) {
      Rueckmeldung.zeigeFehler(kontext, text);
      await tester.pump();
    }

    expect(find.text('Erste.'), findsNothing);
    expect(find.text('Zweite.'), findsOneWidget);
    expect(find.text('Dritte.'), findsOneWidget);
    expect(find.text('Vierte.'), findsOneWidget);
  });

  testWidgets('derselbe Text erscheint kein zweites Mal', (tester) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeFehler(kontext, 'Datei ist in Word geöffnet.');
    await tester.pump();
    Rueckmeldung.zeigeFehler(kontext, 'Datei ist in Word geöffnet.');
    await tester.pump();

    expect(find.text('Datei ist in Word geöffnet.'), findsOneWidget);
  });

  testWidgets('liegt über der Dialogbarriere und ist dort bedienbar', (
    tester,
  ) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    unawaited(
      showDialog<void>(
        context: kontext,
        builder: (_) => const AlertDialog(content: Text('Dialog steht offen.')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dialog steht offen.'), findsOneWidget);

    Rueckmeldung.zeigeFehler(kontext, 'Speichern fehlgeschlagen.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Speichern fehlgeschlagen.'), findsOneWidget);

    // Trifft der Druck den Knopf, liegt die Karte ueber der Barriere — sonst
    // schluckt die Barriere ihn und die Meldung steht weiter da.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Speichern fehlgeschlagen.'), findsNothing);
    expect(
      find.text('Dialog steht offen.'),
      findsOneWidget,
      reason: 'Das Schliessen der Meldung darf den Dialog nicht mitnehmen.',
    );
  });

  testWidgets('die Aktion wird ausgeführt und schließt die Meldung', (
    tester,
  ) async {
    var versuche = 0;
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeFehler(
      kontext,
      'Zentralruf nicht erreichbar.',
      aktion: RueckmeldungsAktion(
        text: 'Erneut versuchen',
        beiDruck: () => versuche++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();

    expect(versuche, 1);
    expect(find.text('Zentralruf nicht erreichbar.'), findsNothing);
  });

  testWidgets(
    'eine erneute Meldung ersetzt die Aktion der stehenden, statt sie zu '
    'verwerfen',
    (tester) async {
      var altVersuche = 0;
      var neuVersuche = 0;
      late BuildContext kontext;
      await tester.pumpWidget(probe((context) => kontext = context));

      final alt = RueckmeldungsAktion(
        text: 'Erneut versuchen',
        beiDruck: () => altVersuche++,
      );
      Rueckmeldung.zeigeFehler(
        kontext,
        'Zentralruf nicht erreichbar.',
        aktion: alt,
      );
      await tester.pump();
      Rueckmeldung.zeigeFehler(
        kontext,
        'Zentralruf nicht erreichbar.',
        aktion: alt,
      );
      await tester.pump();

      final neu = RueckmeldungsAktion(
        text: 'Erneut versuchen',
        beiDruck: () => neuVersuche++,
      );
      Rueckmeldung.zeigeFehler(
        kontext,
        'Zentralruf nicht erreichbar.',
        aktion: neu,
      );
      await tester.pump();

      expect(find.text('Zentralruf nicht erreichbar.'), findsOneWidget);

      await tester.tap(find.text('Erneut versuchen'));
      await tester.pump();

      expect(altVersuche, 0);
      expect(neuVersuche, 1);
    },
  );

  testWidgets('der vor einem await gefasste Handle zeigt danach noch', (
    tester,
  ) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    final rueckmeldung = Rueckmeldung.von(kontext);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    rueckmeldung.erfolg('Vorgang gespeichert.');
    await tester.pump();

    expect(find.text('Vorgang gespeichert.'), findsOneWidget);
  });

  testWidgets('ein neuer Baum unter der Meldung wirft keine Ausnahme', (
    tester,
  ) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeErfolg(kontext, 'Vorgang gespeichert.');
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
    expect(find.text('Vorgang gespeichert.'), findsNothing);
  });

  testWidgets('ausblenden schließt alle stehenden Meldungen', (tester) async {
    late BuildContext kontext;
    await tester.pumpWidget(probe((context) => kontext = context));

    Rueckmeldung.zeigeFehler(kontext, 'Erste Meldung.');
    await tester.pump();
    Rueckmeldung.zeigeFehler(kontext, 'Zweite Meldung.');
    await tester.pump();

    Rueckmeldung.von(kontext).ausblenden();
    await tester.pump();

    expect(find.text('Erste Meldung.'), findsNothing);
    expect(find.text('Zweite Meldung.'), findsNothing);
  });
}
