import 'package:automation_app/core/dateien/datei_oeffnen_mit_hinweis.dart';
import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der eine Weg „Datei öffnen, sonst Hinweis mit ‚Im Ordner zeigen‘“. Die Naht
/// ist [DateiOeffner.oeffne] — ein Widget-Test darf keinen Prozess starten.
void main() {
  const pfad = r'C:\Kanzlei\Anhänge\Gutachten Müller.pdf';
  const hinweis =
      '„Gutachten Müller.pdf“ lässt sich nicht öffnen — '
      'liegt die Datei noch dort?';

  late List<String> geoeffnet;
  late List<String> gezeigt;

  setUp(() {
    geoeffnet = [];
    gezeigt = [];
    DateiOeffner.zeigeImOrdner = (p) async => gezeigt.add(p);
    addTearDown(DateiOeffner.zuruecksetzen);
  });

  Future<void> druckeKnopf(WidgetTester tester, {String? name}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  DateiOeffnenMitHinweis.oeffne(context, pfad, name: name),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets('ließ sich die Datei öffnen, kommt keine Rückmeldung', (
    tester,
  ) async {
    DateiOeffner.oeffne = (p) async {
      geoeffnet.add(p);
      return true;
    };

    await druckeKnopf(tester);

    expect(geoeffnet, [pfad]);
    expect(find.textContaining('lässt sich nicht öffnen'), findsNothing);
    expect(find.text('Im Ordner zeigen'), findsNothing);
  });

  testWidgets('sonst nennt der Hinweis den Dateinamen, nicht den Pfad', (
    tester,
  ) async {
    DateiOeffner.oeffne = (_) async => false;

    await druckeKnopf(tester);

    expect(find.text(hinweis), findsOneWidget);
    expect(find.textContaining(r'C:\Kanzlei'), findsNothing);
  });

  testWidgets('„Im Ordner zeigen“ ruft zeigeImOrdner mit dem Pfad auf', (
    tester,
  ) async {
    DateiOeffner.oeffne = (_) async => false;

    await druckeKnopf(tester);
    await tester.tap(find.text('Im Ordner zeigen'));
    await tester.pump();

    expect(gezeigt, [pfad]);
  });

  testWidgets('ein vom Aufrufer gegebener Name ersetzt den Dateinamen', (
    tester,
  ) async {
    DateiOeffner.oeffne = (_) async => false;

    await druckeKnopf(tester, name: 'Brief an die Versicherung.pdf');

    expect(
      find.text(
        '„Brief an die Versicherung.pdf“ lässt sich nicht öffnen — '
        'liegt die Datei noch dort?',
      ),
      findsOneWidget,
    );
  });
}
