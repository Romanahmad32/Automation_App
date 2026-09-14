import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_aktionen.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_zeile.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_ansicht_umschalter.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_detail.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_detail_kopf.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_html_ansicht.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_vorschlag_karte.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deckt die Detailansicht des Posteingangs (Issue #134) ab: Kopf,
/// Vorschlagskarte, Ansicht-Umschalter, HTML-Ansicht und die Anhangzeile —
/// je einzeln, sowie die zusammengesetzte Hülle unter Last
/// (Schriftgröße/Breite).
void main() {
  PosteingangEintrag eintrag({String betreff = 'Rückfrage zum Schaden'}) =>
      PosteingangEintrag(
        id: '1',
        betreff: betreff,
        absender: '"Max Muster" <max@x.de>',
      );

  Vorgang vorgang() => Vorgang(
    referenz: '144/26 C03',
    angefragtAm: DateTime(2026, 1, 10),
    mandantName: 'Erika Musterfrau',
    kennzeichen: 'HG-E 1427',
  );

  group('PosteingangDetailKopf', () {
    testWidgets('zeigt Von, An, Cc und Datum', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosteingangDetailKopf(
              eintrag: eintrag(),
              inhalt: PosteingangInhalt(
                text: 'Text',
                absenderName: 'Max Muster',
                absenderAdresse: 'max@x.de',
                an: const ['kanzlei@example.de'],
                cc: const ['zweite@example.de'],
                datum: DateTime(2026, 9, 13, 14, 5),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Max Muster <max@x.de>'), findsOneWidget);
      expect(find.text('An:'), findsOneWidget);
      expect(find.textContaining('kanzlei@example.de'), findsOneWidget);
      expect(find.text('Cc:'), findsOneWidget);
      expect(find.textContaining('zweite@example.de'), findsOneWidget);
      expect(find.textContaining('13.09.2026 14:05'), findsOneWidget);
    });

    testWidgets('Cc entfaellt, wenn die Nachricht keine Kopie traegt', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosteingangDetailKopf(
              eintrag: eintrag(),
              inhalt: const PosteingangInhalt(
                text: 'Text',
                an: ['kanzlei@example.de'],
              ),
            ),
          ),
        ),
      );

      expect(find.text('An:'), findsOneWidget);
      expect(find.text('Cc:'), findsNothing);
    });
  });

  group('PosteingangAnsichtUmschalter', () {
    testWidgets('zeigt Formatiert und Text, meldet den Wechsel', (
      tester,
    ) async {
      var wert = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: PosteingangAnsichtUmschalter(
                formatiert: wert,
                onChanged: (v) => setState(() => wert = v),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Formatiert'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);

      await tester.tap(find.text('Text'));
      await tester.pump();
      expect(wert, isFalse);
    });
  });

  group('PosteingangHtmlAnsicht', () {
    testWidgets('rendert ohne Netzwerkzugriff und zeigt den Bilder-Hinweis', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosteingangHtmlAnsicht(
              html:
                  '<p>Hallo Kanzlei</p>'
                  '<img src="" data-blockiert="1">',
              bilderBlockiert: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // `HtmlWidget` baut nacktes `RichText` statt `Text` — ohne
      // `findRichText: true` sieht der Finder diesen Text nicht.
      expect(find.text('Hallo Kanzlei', findRichText: true), findsOneWidget);
      expect(find.text('Externe Bilder werden nicht geladen.'), findsOneWidget);
      // Das Bild selbst wird nie als Netzwerkbild angefragt — nur das
      // Platzhaltersymbol steht an seiner Stelle.
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ohne Hinweis, wenn nichts blockiert wurde', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosteingangHtmlAnsicht(html: '<p>Ohne Bild</p>'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Externe Bilder werden nicht geladen.'), findsNothing);
    });
  });

  group('PosteingangVorschlagKarte', () {
    testWidgets('zeigt "Vorgang …" bei sicherem Bezug, meldet beide Knoepfe', (
      tester,
    ) async {
      var zumVorgang = 0;
      var nichtZuordnen = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosteingangVorschlagKarte(
              bezug: Vorgangsbezug(
                vorgang: vorgang(),
                sicherheit: BezugSicherheit.sicher,
                grund: 'Zeichen 144/26 C03 steht im Betreff',
              ),
              onZumVorgang: () => zumVorgang++,
              onNichtZuordnen: () => nichtZuordnen++,
            ),
          ),
        ),
      );

      expect(find.text('Vorgang 144/26 C03'), findsOneWidget);
      expect(find.textContaining('Erika Musterfrau'), findsOneWidget);
      expect(find.textContaining('HG-E 1427'), findsOneWidget);
      expect(
        find.textContaining('Zeichen 144/26 C03 steht im Betreff'),
        findsOneWidget,
      );

      await tester.tap(find.text('Zum Vorgang'));
      await tester.tap(find.text('Nicht zuordnen'));
      expect(zumVorgang, 1);
      expect(nichtZuordnen, 1);
    });

    testWidgets('zeigt "Vermutlich zu Vorgang …" bei vermutetem Bezug', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosteingangVorschlagKarte(
              bezug: Vorgangsbezug(
                vorgang: vorgang(),
                sicherheit: BezugSicherheit.vermutet,
                grund: 'Absender ist der Mandant Erika Musterfrau',
              ),
              onZumVorgang: () {},
              onNichtZuordnen: () {},
            ),
          ),
        ),
      );

      expect(find.text('Vermutlich zu Vorgang 144/26 C03'), findsOneWidget);
    });
  });

  group('PosteingangAnhangZeile', () {
    // Die Größenformatierung selbst prüft
    // test/core/dateigroesse_format_test.dart — hier nur, dass die Zeile sie
    // tatsächlich anzeigt.
    testWidgets('zeigt Namen, Groesse und ruft Oeffnen auf', (tester) async {
      PosteingangAnhang? geoeffnet;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosteingangAnhangZeile(
              anhang: const PosteingangAnhang(
                id: '2',
                dateiname: 'Gutachten.pdf',
                groesse: 2516582,
                medientyp: 'application/pdf',
              ),
              aktionen: PosteingangAnhangAktionen(
                onOeffnen: (a) async => geoeffnet = a,
                onInDieAkte: (_) async {},
                onBeimVersand: (_) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Gutachten.pdf'), findsOneWidget);
      expect(find.text('2,4 MB'), findsOneWidget);

      await tester.tap(find.byTooltip('Öffnen'));
      await tester.pump();
      expect(geoeffnet?.dateiname, 'Gutachten.pdf');
    });

    testWidgets('zeigt einen Ring statt der Knoepfe, waehrend es laeuft', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosteingangAnhangZeile(
              anhang: const PosteingangAnhang(id: '2', dateiname: 'a.pdf'),
              aktionen: PosteingangAnhangAktionen(
                onOeffnen: (_) async {},
                onInDieAkte: (_) async {},
                onBeimVersand: (_) async {},
                ladenderAnhangId: '2',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Öffnen'), findsNothing);
    });

    testWidgets(
      'zeigt den Ring nur an der eigenen Zeile, nicht an einer anderen '
      '(Review #134, Befund 7)',
      (tester) async {
        final aktionen = PosteingangAnhangAktionen(
          onOeffnen: (_) async {},
          onInDieAkte: (_) async {},
          onBeimVersand: (_) async {},
          ladenderAnhangId: '2',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PosteingangAnhangZeile(
                    anhang: const PosteingangAnhang(
                      id: '2',
                      dateiname: 'a.pdf',
                    ),
                    aktionen: aktionen,
                  ),
                  PosteingangAnhangZeile(
                    anhang: const PosteingangAnhang(
                      id: '3',
                      dateiname: 'b.pdf',
                    ),
                    aktionen: aktionen,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byTooltip('Öffnen'), findsOneWidget);
      },
    );
  });

  group('PosteingangDetail', () {
    testWidgets('laeuft bei "Am groessten" und 420px Breite nicht ueber', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: MaterialTheme(
            ThemeData.light().textTheme,
            schriftstufe: Schriftstufe.amGroessten,
          ).light(),
          home: Scaffold(
            body: PosteingangDetail(
              eintrag: eintrag(
                betreff:
                    'Sehr lange Betreffzeile mit vielen Wörtern, damit '
                    'die Kopfzeile bei großer Schrift wirklich umbricht',
              ),
              inhalt: PosteingangInhalt(
                text: 'Ein Beispieltext für die Detailansicht.',
                html:
                    '<p>Ein Beispieltext für die Detailansicht.</p>'
                    '<img src="" data-blockiert="1">',
                bilderBlockiert: true,
                absenderName: 'Eine sehr lange Absenderbezeichnung GmbH',
                absenderAdresse: 'eine.sehr.lange.adresse@versicherung.de',
                an: const ['kanzlei@example.de', 'zweite.adresse@example.de'],
                cc: const ['dritte.adresse@example.de'],
                datum: DateTime(2026, 9, 13, 14, 5),
                anhaenge: const [
                  PosteingangAnhang(
                    id: '2',
                    dateiname: 'Ein sehr langer Dateiname für den Anhang.pdf',
                    groesse: 2516582,
                    medientyp: 'application/pdf',
                  ),
                ],
              ),
              onErneutVersuchen: () {},
              bezug: Vorgangsbezug(
                vorgang: vorgang(),
                sicherheit: BezugSicherheit.vermutet,
                grund: 'Absender ist der Versicherer HUK-COBURG',
              ),
              onZumVorgang: () {},
              onNichtZuordnen: () {},
              onAntworten: () {},
              onMailInDieAkte: () {},
              onMailBeimVersand: () {},
              onAnhangOeffnen: (_) async {},
              onAnhangInDieAkte: (_) async {},
              onAnhangBeimVersand: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
