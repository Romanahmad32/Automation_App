import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
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
    ValueChanged<RegisterZeile>? onVorgangZeile,
    ValueChanged<RegisterZeile>? onLoeschen,
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
              onVorgangZeile: onVorgangZeile,
              onLoeschen: onLoeschen,
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

    /// §6.2: Eine historische Zeile trägt in der Ansicht **immer** den Status
    /// „Historie" — und nur ihn. Der zweite Chip daneben machte aus einer
    /// Spalte mit einer Aussage eine mit zweien; was auffiel, steht im
    /// Herkunftskasten des Bearbeiten-Dialogs.
    testWidgets('auch eine auffällige Zeile trägt nur „Historie"', (
      tester,
    ) async {
      await tabellenBreite(
        tester,
        1600,
        mitStatus: true,
        zeilen: [
          historieZeile(
            zeichen: '11/19 C02',
            historieId: 8,
            befunde: const ['Ohne Abteilung.'],
            sicherheit: RegisterSicherheiten.niedrig,
          ),
        ],
      );

      expect(find.text('Historie'), findsOneWidget);
      expect(find.text('1 Befund'), findsNothing);
      expect(find.text('sehr unsicher'), findsNothing);
    });

    /// Ein Klick öffnet den Bearbeiten-Dialog — das ist keine Mehrfachauswahl.
    /// Das „alle auswählen" in der Kopfzeile rief den Rückruf für **jede**
    /// Zeile auf und legte so einen Dialog über den nächsten.
    testWidgets('es gibt keine Ankreuzspalte', (tester) async {
      var geklickt = 0;
      await tabellenBreite(
        tester,
        1600,
        zeilen: [
          historieZeile(),
          historieZeile(zeichen: 'b', historieId: 8),
        ],
        onHistorieZeile: (_) => geklickt++,
      );

      expect(find.byType(Checkbox), findsNothing);
      expect(geklickt, 0);
    });

    /// Ohne sie war bei fünf Spalten und langen Rubren nicht zu sehen, wo
    /// „Sache" aufhört und „Rechtsgebiet" anfängt.
    testWidgets('eine dünne Linie trennt die Spalten', (tester) async {
      await tabellenBreite(tester, 1600, mitStatus: true);

      final tabelle = tester.widget<DataTable>(find.byType(DataTable));
      expect(tabelle.border?.verticalInside.width, greaterThan(0));
    });

    /// Das Register ist ein Verzeichnis: Man findet dort eine Sache wieder und
    /// will dann an sie heran. Historie und Vorgang führen dabei an
    /// verschiedene Orte — Berichtigung hier, Vorgangsverwaltung dort.
    testWidgets('jede Herkunft meldet an ihren eigenen Rückruf', (
      tester,
    ) async {
      final historie = <String>[];
      final vorgaenge = <String>[];
      await tabellenBreite(
        tester,
        1600,
        zeilen: [
          historieZeile(zeichen: '10/19 C02'),
          vorgangsZeile(),
        ],
        onHistorieZeile: (zeile) => historie.add(zeile.zeichen),
        onVorgangZeile: (zeile) => vorgaenge.add(zeile.zeichen),
      );

      await tester.tap(find.text('10/19 C02'));
      await tester.tap(find.text('01/26 C03'));
      await tester.pump();

      expect(historie, ['10/19 C02']);
      expect(vorgaenge, ['01/26 C03']);
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

  group('Löschen-Spalte (§6.3)', () {
    testWidgets('ohne onLoeschen erscheint kein Papierkorb', (tester) async {
      await tabellenBreite(
        tester,
        1600,
        zeilen: [historieZeile(), vorgangsZeile()],
      );

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('mit onLoeschen trägt jede Zeile einen Papierkorb', (
      tester,
    ) async {
      await tabellenBreite(
        tester,
        1600,
        zeilen: [historieZeile(), vorgangsZeile()],
        onLoeschen: (_) {},
      );

      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('ein Klick auf den Papierkorb meldet genau diese Zeile', (
      tester,
    ) async {
      final geloescht = <String>[];
      await tabellenBreite(
        tester,
        1600,
        zeilen: [
          historieZeile(zeichen: '10/19 C02'),
          vorgangsZeile(),
        ],
        onLoeschen: (zeile) => geloescht.add(zeile.zeichen),
      );

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();

      expect(geloescht, ['10/19 C02']);
    });

    /// `DataCell.onTap` überschreibt für diese eine Zelle das
    /// `onSelectChanged` der Zeile — sonst öffnete ein Klick auf den
    /// Papierkorb zusätzlich den Bearbeiten-Dialog.
    testWidgets('ein Klick auf den Papierkorb öffnet nicht auch die Zeile', (
      tester,
    ) async {
      final angeklickt = <String>[];
      final geloescht = <String>[];
      await tabellenBreite(
        tester,
        1600,
        zeilen: [historieZeile(zeichen: '10/19 C02')],
        onHistorieZeile: (zeile) => angeklickt.add(zeile.zeichen),
        onLoeschen: (zeile) => geloescht.add(zeile.zeichen),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(geloescht, ['10/19 C02']);
      expect(angeklickt, isEmpty);
    });

    testWidgets('kommt mit Jahreszeilen und Statusspalte ohne Fehler aus', (
      tester,
    ) async {
      await tabellenBreite(
        tester,
        1600,
        mitJahreszeilen: true,
        mitStatus: true,
        zeilen: [
          historieZeile(jahr: '2019'),
          vorgangsZeile(jahr: '2026'),
        ],
        onLoeschen: (_) {},
      );

      expect(tester.takeException(), isNull);
    });
  });
}
