import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_befund_chip.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_tabelle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Die Registertabelle soll den verfügbaren Platz ausnutzen statt links in
/// einer schmalen Spalte zu kleben — auf der Registerseite wie in der
/// Startseiten-Karte. Ist das Fenster zu schmal für den Inhalt, wächst sie
/// über den Rand hinaus (und wird scrollbar), statt die Spalten zu quetschen.
///
/// Seit Issue #109 zeigt sie außerdem beide Quellen in einer Folge: laufende
/// Vorgänge und die übernommene Historie, getrennt von Jahresüberschriften.
void main() {
  RegisterZeile zeile(int nummer) => vorgangsZeile(
    nummer: nummer,
    zeichen: '$nummer/26 C03',
    parteien: 'Mustermann, Max ./. HUK-COBURG',
    sachbestand: 'Sachverhalt v. 20.06.2026',
    referenz: '$nummer/26 C03_HG-E 1427',
  );

  /// Baut die Tabelle in einem [breite] Pixel breiten Bereich auf und liefert
  /// die tatsächlich gerenderte Tabellenbreite.
  Future<double> tabellenBreite(
    WidgetTester tester,
    double breite, {
    List<RegisterZeile>? zeilen,
    bool mitJahreszeilen = false,
    bool mitStatus = false,
    ValueChanged<RegisterZeile>? onHistorieZeile,
  }) async {
    // Reichlich Platz, damit [breite] nie vom Fenster beschnitten wird.
    tester.view.physicalSize = const Size(4000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: breite,
            child: RegisterTabelle(
              zeilen: zeilen ?? [zeile(215), zeile(216)],
              mitJahreszeilen: mitJahreszeilen,
              mitStatus: mitStatus,
              onHistorieZeile: onHistorieZeile,
            ),
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

  group('Sache und Sachbestand', () {
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

    /// „Sache" und nicht „Name ./. Gegner": Der Bestand kennt zwei Formen, und
    /// für „Bußgeldsache Erika Musterfrau" gibt es keine Gegenseite. Dieselbe
    /// Überschrift steht in der Word-/PDF-Fassung (`RegisterLayout`).
    testWidgets('werden von der Überschrift einzeln beschriftet', (
      tester,
    ) async {
      await tabellenBreite(tester, RegisterTabelle.nebeneinanderAb + 1000);

      expect(find.text('Sache'), findsOneWidget);
      expect(find.text('Name ./. Gegner'), findsNothing);
      // „Sachbestand" steht bündig darüber, nicht über der Sache — DataTable
      // setzt Überschriften sonst starr nach links.
      expect(
        tester.getRect(find.text('Sachbestand')).right,
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

  group('Historie und Vorgänge in einer Folge', () {
    /// Wie im Registerbuch: Vor jedem Jahrgang steht seine Jahreszahl — auch
    /// vor dem ersten, genau wie `RegisterDokument` sie in die Datei setzt.
    testWidgets('setzt bei jedem Jahrgangswechsel eine Jahreszeile', (
      tester,
    ) async {
      await tabellenBreite(
        tester,
        1600,
        mitJahreszeilen: true,
        zeilen: [
          historieZeile(jahr: '2019', zeichen: '10/19 C02'),
          historieZeile(jahr: '2019', zeichen: '11/19 C02', historieId: 8),
          vorgangsZeile(jahr: '2026'),
        ],
      );

      expect(find.text('2019'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('ohne Jahreszeilen bleibt der Ausschnitt eine Liste', (
      tester,
    ) async {
      await tabellenBreite(tester, 1600, zeilen: [historieZeile(jahr: '2019')]);

      expect(find.text('2019'), findsNothing);
    });

    testWidgets('jede historische Zeile trägt den Chip „Historie"', (
      tester,
    ) async {
      await tabellenBreite(
        tester,
        1600,
        mitStatus: true,
        zeilen: [
          historieZeile(zeichen: '10/19 C02'),
          historieZeile(zeichen: '11/19 C02', historieId: 8),
          vorgangsZeile(),
        ],
      );

      expect(find.text('Historie'), findsNWidgets(2));
    });

    /// Sonst stünde an jeder der tausenden Zeilen ein Hinweis, und
    /// „auffällig" hieße nichts mehr.
    testWidgets('der Befund-Chip steht nur an auffälligen Zeilen', (
      tester,
    ) async {
      await tabellenBreite(
        tester,
        1600,
        mitStatus: true,
        zeilen: [
          historieZeile(zeichen: '10/19 C02'),
          historieZeile(
            zeichen: '11/19 C02',
            historieId: 8,
            befunde: const ['Ohne Abteilung.'],
          ),
        ],
      );

      expect(find.byType(RegisterBefundChip), findsOneWidget);
      expect(find.text('1 Befund'), findsOneWidget);
    });

    testWidgets('nur historische Zeilen lassen sich anklicken', (tester) async {
      final angeklickt = <String>[];
      await tabellenBreite(
        tester,
        1600,
        zeilen: [
          historieZeile(zeichen: '10/19 C02'),
          vorgangsZeile(),
        ],
        onHistorieZeile: (zeile) => angeklickt.add(zeile.zeichen),
      );

      await tester.tap(find.text('10/19 C02'));
      await tester.tap(find.text('01/26 C03'));
      await tester.pump();

      expect(angeklickt, ['10/19 C02']);
    });
  });
}
