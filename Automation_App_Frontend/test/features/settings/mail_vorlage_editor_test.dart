import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlage_zustand.dart';
import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/betreff_text_felder.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagen_hinweise_knopf.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_dialog.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_vorschau.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Vorlageneditor (§4.7, Issue #107): Er zeigt, **was aus der Vorlage
/// wird**, während sie geschrieben wird — und er teilt seine Bausteine mit dem
/// Versanddialog.
///
/// Der Mangel, den diese Datei festhält: Man schrieb blind. Wie `{{Anrede}}`
/// oder `{{MandantName}}` am Ende aussehen, sah der Anwalt erst Wochen später
/// im Versanddialog, an einer Vorlage, die längst als fertig galt.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    MailVorlage vorlage = const MailVorlage(),
    double breite = 1200,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(breite, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MailVorlageDialog(
            vorlage: vorlage,
            onSpeichern: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Das Nachrichtenfeld — es trägt den Zusatz „Ziel für Platzhalter", solange
  /// es das Einfügeziel ist.
  Finder nachrichtenfeld() => find.widgetWithText(
    TextField,
    BetreffTextFelder.beschriftung(
      PlatzhalterEinfuegeZiel.textName,
      istZiel: true,
    ),
  );

  group('die Vorschau läuft mit', () {
    testWidgets('sie zeigt die ausgefüllte Fassung, nicht die Vorlage', (
      tester,
    ) async {
      await zeige(
        tester,
        vorlage: const MailVorlage(
          id: 1,
          name: 'Anschreiben',
          betreff: 'Sache {{MandantName}}',
          text: '{{Anrede}},\n\nes geht um {{Kennzeichen}}.',
        ),
      );

      expect(find.byType(MailVorlageVorschau), findsOneWidget);
      expect(find.byType(EmailVorschau), findsOneWidget);
      expect(
        find.textContaining('Sehr geehrte Frau Muster'),
        findsWidgets,
        reason: 'die Beispiel-Anrede steht eingesetzt da, nicht {{Anrede}}',
      );
      expect(find.textContaining('Sache Anna Muster'), findsWidgets);
    });

    testWidgets('sie zieht beim Tippen nach', (tester) async {
      await zeige(tester);

      await tester.enterText(nachrichtenfeld(), 'Zeichen: {{Referenz}}');
      await tester.pump();

      expect(
        find.textContaining('Zeichen: 12/26 C01_HG-E 1427'),
        findsWidgets,
        reason:
            'ohne Nachziehen sähe der Anwalt seine Vorlage, nicht ihr Ergebnis',
      );
    });

    testWidgets('ein offener Platzhalter bleibt in der Vorschau sichtbar', (
      tester,
    ) async {
      // Genau die Auskunft, die der Editor vorher nicht gab: Ein Name, der auf
      // kein Feld auflöst, sieht in der Vorlage aus wie jeder andere.
      await zeige(tester);

      await tester.enterText(nachrichtenfeld(), 'Hallo {{Adresse}}');
      await tester.pump();

      expect(find.textContaining('Hallo {{Adresse}}'), findsWidgets);
    });
  });

  group('die Platzhalterhilfe steht offen', () {
    testWidgets('sie ist ohne Aufklappen da und nennt ihr Ziel', (
      tester,
    ) async {
      // Vorher war sie ein zugeklapptes `ExpansionTile` — beim Anlegen der
      // ersten Vorlage zu, und wer die erste schreibt, kennt die Namen nicht.
      await zeige(tester);

      expect(find.byType(PlatzhalterAuswahl), findsOneWidget);
      expect(
        find.text(PlatzhalterAuswahl.kopfzeile('Nachricht')),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsNothing);
    });
  });

  group('die Mängelauskunft steckt hinter dem „?"-Knopf', () {
    testWidgets('sie steht nicht mehr fest im Formular', (tester) async {
      // Der Block schob die Platzhalterhilfe aus dem Fenster — ausgerechnet
      // die Liste, die die Mängel behebt.
      await zeige(
        tester,
        vorlage: const MailVorlage(id: 1, name: 'X', text: '{{Adresse}}'),
      );

      expect(find.byType(VorlagenHinweiseKnopf), findsOneWidget);
      expect(find.textContaining('kein Feld dieses Namens'), findsNothing);

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('kein Feld dieses Namens'), findsOneWidget);
    });
  });

  group('das Zustandsabzeichen der Übersicht', () {
    test('eine Vorlage ohne Text ist nicht vollständig', () {
      final zustand = MailVorlageZustand.fuer(
        const MailVorlage(id: 1, name: 'Leer', betreff: 'Betreff'),
      );

      expect(zustand.text, 'Ohne Text');
      expect(zustand.inOrdnung, isFalse);
    });

    test('lauter auflösende Platzhalter heißen „Vollständig"', () {
      final zustand = MailVorlageZustand.fuer(
        const MailVorlage(
          id: 1,
          name: 'Gut',
          betreff: 'Sache {{MandantName}}',
          text: '{{Anrede}},\n\nzu {{Referenz}}.',
        ),
      );

      expect(zustand.text, 'Vollständig');
      expect(zustand.inOrdnung, isTrue);
    });

    test('offene werden gezählt, und der Plural wird gebeugt', () {
      expect(
        MailVorlageZustand.fuer(
          const MailVorlage(id: 1, name: 'Eins', text: 'Hallo {{Adresse}}'),
        ).text,
        'Ein Platzhalter offen',
      );
      expect(
        MailVorlageZustand.fuer(
          const MailVorlage(
            id: 2,
            name: 'Zwei',
            betreff: '{{Postfach}}',
            text: 'Hallo {{Adresse}}',
          ),
        ).text,
        '2 Platzhalter offen',
        reason: '„1 Platzhalter offen" wäre ein Schnitzer',
      );
    });
  });
}
