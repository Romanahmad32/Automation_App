import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_tabelle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Registertabelle soll den verfügbaren Platz ausnutzen statt links in
/// einer schmalen Spalte zu kleben — auf der Registerseite wie in der
/// Startseiten-Karte. Ist das Fenster zu schmal für den Inhalt, wächst sie
/// über den Rand hinaus (und wird scrollbar), statt die Spalten zu quetschen.
void main() {
  Vorgang zeile(int nummer) => Vorgang(
    referenz: '$nummer/26 C03_HG-E 1427',
    angefragtAm: DateTime(2026, 6, 20),
    laufendeNummer: nummer,
    jahr: '26',
    abteilung: 'C03',
    mandantName: 'Mustermann, Max',
    gegner: 'HUK-COBURG',
    unfallDatum: '20.06.2026',
  );

  /// Baut die Tabelle in einem [breite] Pixel breiten Bereich auf und liefert
  /// die tatsächlich gerenderte Tabellenbreite.
  Future<double> tabellenBreite(WidgetTester tester, double breite) async {
    // Reichlich Platz, damit [breite] nie vom Fenster beschnitten wird.
    tester.view.physicalSize = const Size(4000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: breite,
            child: RegisterTabelle(zeilen: [zeile(215), zeile(216)]),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(DataTable)).width;
  }

  testWidgets('füllt die verfügbare Breite vollständig aus', (tester) async {
    expect(await tabellenBreite(tester, 1600), 1600);
  });

  testWidgets('Spalte 2 heißt „Zeichen" und trägt es ohne Kennzeichen', (
    tester,
  ) async {
    await tabellenBreite(tester, 1600);

    expect(find.text('Zeichen'), findsOneWidget);
    expect(find.text('215/26 C03'), findsOneWidget);
    // Das Kennzeichen gehört zur Referenz, nicht ins Register: Die Spalte muss
    // dasselbe zeigen wie `RegisterZeilenBau.Zeichen` in der Kanzleidatei.
    expect(find.text('215/26 C03_HG-E 1427'), findsNothing);
  });

  testWidgets('wächst mit der verfügbaren Breite mit', (tester) async {
    final schmal = await tabellenBreite(tester, 1200);
    final breit = await tabellenBreite(tester, 1600);

    expect(breit, greaterThan(schmal));
  });

  testWidgets('quetscht die Spalten nicht, wenn der Platz nicht reicht', (
    tester,
  ) async {
    // Statt die Spalten unleserlich zu stauchen, bleibt die Tabelle so breit
    // wie ihr Inhalt — die waagerechte Scrollleiste übernimmt den Rest.
    expect(await tabellenBreite(tester, 400), greaterThan(400));
    expect(tester.takeException(), isNull);
  });

  group('Parteien und Sachbestand', () {
    final parteien = find.text('Mustermann, Max ./. HUK-COBURG');
    final sachbestand = find.text('Sachverhalt v. 20.06.2026');

    testWidgets('stehen auf breiten Fenstern nebeneinander', (tester) async {
      await tabellenBreite(tester, RegisterTabelle.nebeneinanderAb + 1000);

      expect(parteien, findsWidgets);
      // Gleiche Zeile (gleiche Höhe), Sachbestand rechts davon.
      final links = tester.getRect(parteien.first);
      final rechts = tester.getRect(sachbestand.first);
      expect(rechts.top, closeTo(links.top, 1));
      expect(rechts.left, greaterThan(links.right));
    });

    testWidgets('nutzen dabei die volle Spaltenbreite', (tester) async {
      await tabellenBreite(tester, RegisterTabelle.nebeneinanderAb + 1000);
      final schmal = tester.getRect(sachbestand.first).left;

      await tabellenBreite(tester, RegisterTabelle.nebeneinanderAb + 1600);
      final breit = tester.getRect(sachbestand.first).left;

      // Der Sachbestand rückt mit der Spalte nach rechts, statt am Namen zu
      // kleben und die Spalte leer wirken zu lassen.
      expect(breit, greaterThan(schmal));
    });

    testWidgets('werden von der Überschrift einzeln beschriftet', (
      tester,
    ) async {
      await tabellenBreite(tester, RegisterTabelle.nebeneinanderAb + 1000);

      // „Sachverhalt" steht bündig über dem Sachbestand, nicht über den
      // Parteien — DataTable setzt Überschriften sonst starr nach links.
      expect(
        tester.getRect(find.text('Sachverhalt')).right,
        closeTo(tester.getRect(sachbestand.first).right, 2),
      );
    });

    testWidgets('stehen auf schmalen Fenstern untereinander', (tester) async {
      await tabellenBreite(tester, RegisterTabelle.nebeneinanderAb - 200);

      expect(parteien, findsNothing);
      expect(
        find.text('Mustermann, Max ./. HUK-COBURG\nSachverhalt v. 20.06.2026'),
        findsWidgets,
      );
    });
  });
}
