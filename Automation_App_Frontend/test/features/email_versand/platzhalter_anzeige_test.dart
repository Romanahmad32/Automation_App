import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/beugung.dart';
import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/beugung_vorschau.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/grussformel_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/handarbeit_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagen_hinweise.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/mail_vorlagen_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_fehlstelle_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_uebersicht.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorgang_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagentext_zeile.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was der Anwalt über einen übersprungenen Platzhalter zu sehen bekommt
/// (§4.7) — und was an den Auswahlfeldern steht.
///
/// Geprüft werden die **Entscheidungen**, nicht das Aussehen: Welcher Satz
/// erscheint, wann er erscheint, und dass eine entfallene Zeile in der
/// Gegenüberstellung als solche erkennbar ist. Genau das war der Mangel: Die
/// Auskunft gab es schon, gelesen hat sie niemand — und sie sagte nichts, was
/// der Anwalt nicht schon wusste.
void main() {
  Widget rahmen(Widget kind) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: kind)),
  );

  group('Überschrift über den Fehlstellen', () {
    test('nennt die Zahl und beugt den Plural', () {
      expect(
        PlatzhalterUebersicht.fehlstellenTitel(1),
        'Ein Platzhalter ohne Wert',
      );
      expect(
        PlatzhalterUebersicht.fehlstellenTitel(3),
        '3 Platzhalter ohne Wert',
      );
    });
  });

  group('wann die Übersicht neu gezeichnet wird', () {
    const vorlage = MailVorlage(id: 1, name: 'V', text: '{{Anrede}}');

    test('die gewählte Anredeart zählt dazu', () {
      // Der behobene Fehler (03.09.2026): Sie fehlte in der Liste, und weil
      // das Widget im Formular `const` ist, half auch der Neuaufbau von oben
      // nicht. Die Übersicht zeigte „Mandant", der Text darunter „Mandantin".
      expect(
        PlatzhalterUebersicht.neuZeichnen(
          const EmailEntwurfState(gewaehlteVorlage: vorlage),
          const EmailEntwurfState(
            gewaehlteVorlage: vorlage,
            anredeGeschlecht: Anrede.frau,
          ),
        ),
        isTrue,
      );
    });

    test('auch die Anredeart aus dem Register', () {
      expect(
        PlatzhalterUebersicht.neuZeichnen(
          const EmailEntwurfState(gewaehlteVorlage: vorlage),
          const EmailEntwurfState(
            gewaehlteVorlage: vorlage,
            mandantAnrede: Anrede.herr,
          ),
        ),
        isTrue,
      );
    });

    test('etwas, das keinen Platzhalter füllt, zählt nicht dazu', () {
      // Die Gegenprobe: `buildWhen` soll nicht zu allem „ja" sagen, sonst
      // rechnet die Übersicht bei jedem Tastendruck im Textfeld neu.
      expect(
        PlatzhalterUebersicht.neuZeichnen(
          const EmailEntwurfState(gewaehlteVorlage: vorlage),
          const EmailEntwurfState(
            gewaehlteVorlage: vorlage,
            versandVersucht: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Hinweis an der Zusatzgruß-Auswahl', () {
    test('eine Vorlage ohne Stelle dafür nennt den Platzhalter', () {
      const ohneStelle = MailVorlage(
        id: 1,
        name: 'Ohne',
        betreff: 'Betreff',
        text: '{{Anrede}},\n\nText.',
      );
      final hinweis = GrussformelChips.hinweisFuer(
        const EmailEntwurfState(
          gewaehlteVorlage: ohneStelle,
          zusatzgruss: 'Salamu aleikum',
        ),
      );

      expect(hinweis, contains('{{Zusatzgruß}}'));
      expect(hinweis, contains('keine Stelle'));
    });

    test('ein Mitleser ist ein Hinweis, keine Sperre', () {
      final hinweis = GrussformelChips.hinweisFuer(
        const EmailEntwurfState(
          zusatzgruss: 'Salamu aleikum',
          mitleserImAn: true,
        ),
      );

      expect(hinweis, contains('geht trotzdem mit'));
    });

    test('ohne gewählten Gruß schweigt der Mitleser-Hinweis', () {
      // Sonst stünde er an jeder gemeinsamen Mail an Mandant und
      // Versicherung — und die ist der Regelfall (§4.7).
      final hinweis = GrussformelChips.hinweisFuer(
        const EmailEntwurfState(mitleserImAn: true),
      );

      expect(hinweis, isNull);
    });
  });

  group('„Keine Vorlage" sagt die Wahrheit', () {
    test('ohne Vorgang verspricht sie keine Vorbelegung', () {
      expect(
        MailVorlagenAuswahlFeld.ohneVorlageText(false),
        contains('kein Vorgang'),
      );
      expect(
        MailVorlagenAuswahlFeld.ohneVorlageText(true),
        'Keine Vorlage (Vorbelegung aus dem Vorgang)',
      );
    });
  });

  group('Vorgang in der Auswahlliste', () {
    test('die Referenz steht voran, danach sucht der Anwalt', () {
      final beschriftung = VorgangAuswahlFeld.beschriftungFuer(
        Vorgang(
          referenz: '84/26 C03_GG-XY 123',
          angefragtAm: DateTime(2026, 6, 20),
          laufendeNummer: 84,
          jahr: '26',
          abteilung: 'C03',
          mandantName: 'Klaus Müller',
          gegner: 'HUK-COBURG',
        ),
      );

      expect(beschriftung, '84/26 C03_GG-XY 123 · Klaus Müller ./. HUK-COBURG');
    });

    test('ohne Parteien bleibt die Referenz allein stehen', () {
      final beschriftung = VorgangAuswahlFeld.beschriftungFuer(
        Vorgang(
          referenz: '85/26 C03',
          angefragtAm: DateTime(2026, 7, 1),
          laufendeNummer: 85,
          jahr: '26',
          abteilung: 'C03',
        ),
      );

      expect(beschriftung, '85/26 C03');
    });
  });

  group('die Fehlstelle sagt, was fehlt und wo es gepflegt wird', () {
    testWidgets('Stelle, Folge und Grund stehen beieinander', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const PlatzhalterFehlstelleZeile(
            befund: PlatzhalterBefund(
              name: 'MandantTelefon',
              zeile: 7,
              zeileEntfaellt: true,
              bezeichnung: 'Mandant · Telefon',
              fehlstelle: 'im Mandantenregister nicht erfasst',
            ),
          ),
        ),
      );

      expect(find.textContaining('{{MandantTelefon}}'), findsOneWidget);
      expect(find.textContaining('in Zeile 7'), findsOneWidget);
      expect(find.textContaining('entfällt ganz'), findsOneWidget);
      expect(
        find.text('Mandant · Telefon: im Mandantenregister nicht erfasst'),
        findsOneWidget,
      );
    });

    testWidgets('ohne Bezeichnung steht nur der Grund', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const PlatzhalterFehlstelleZeile(
            befund: PlatzhalterBefund(
              name: 'Zusatzgruß',
              zeile: 2,
              zeileEntfaellt: true,
              fehlstelle: 'wird oben im Dialog gewählt',
            ),
          ),
        ),
      );

      expect(find.text('wird oben im Dialog gewählt'), findsOneWidget);
    });
  });

  group('die Zeile in der vollständigen Liste', () {
    testWidgets('ein leerer Befund nennt seine Folge', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const PlatzhalterZeile(
            befund: PlatzhalterBefund(
              name: 'Zusatzgruß',
              zeile: 2,
              zeileEntfaellt: true,
            ),
          ),
        ),
      );

      expect(find.text('{{Zusatzgruß}}'), findsOneWidget);
      expect(find.text('bleibt leer — Zeile 2 entfällt'), findsOneWidget);
    });

    testWidgets('ein gefüllter Befund zeigt Wert und Herkunft', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const PlatzhalterZeile(
            befund: PlatzhalterBefund(
              name: 'MandantName',
              wert: 'Klaus Müller',
              herkunft: 'aus dem Vorgang',
              zeile: 4,
            ),
          ),
        ),
      );

      expect(find.text('Klaus Müller'), findsOneWidget);
      expect(find.text('aus dem Vorgang'), findsOneWidget);
    });
  });

  group('Vorlage und Ergebnis nebeneinander', () {
    testWidgets('eine entfallene Zeile nennt den Platzhalter als Grund', (
      tester,
    ) async {
      await tester.pumpWidget(
        rahmen(
          const VorlagentextZeile(
            nummer: 2,
            vorlage: '{{Zusatzgruß}},',
            leere: [
              PlatzhalterBefund(
                name: 'Zusatzgruß',
                zeile: 2,
                zeileEntfaellt: true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget, reason: 'die Zeilennummer');
      expect(find.text('{{Zusatzgruß}},'), findsOneWidget);
      expect(
        find.text('entfällt — {{Zusatzgruß}} ohne Wert'),
        findsOneWidget,
        reason: 'die rechte Spalte tragt die neue Auskunft',
      );
    });

    testWidgets('eine gefüllte Zeile zeigt links und rechts', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const VorlagentextZeile(
            nummer: 1,
            vorlage: '{{Anrede}},',
            ergebnis: 'Sehr geehrter Herr Müller,',
          ),
        ),
      );

      expect(find.text('{{Anrede}},'), findsOneWidget);
      expect(find.text('Sehr geehrter Herr Müller,'), findsOneWidget);
      expect(find.textContaining('entfällt'), findsNothing);
    });

    testWidgets('die Betreffzeile hat keine Nummer', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const VorlagentextZeile(
            nummer: 0,
            vorlage: 'Ihre Sache',
            ergebnis: 'Ihre Sache',
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
      expect(find.text('Ihre Sache'), findsNWidgets(2));
    });
  });

  group('Hinweis an der Anredeart-Auswahl', () {
    test('ohne eigene Wahl gilt das Register und es steht nichts da', () {
      const state = EmailEntwurfState(
        mandantAnrede: Anrede.herr,
        mandantBekannt: true,
      );

      expect(state.anredeartWeichtAb, isFalse);
      expect(state.anredeartNachtragbar, isFalse);
      expect(state.geschlecht, Anrede.herr);
    });

    test('die gleiche Wahl wie im Register ist keine Abweichung', () {
      const state = EmailEntwurfState(
        mandantAnrede: Anrede.frau,
        anredeGeschlecht: Anrede.frau,
        mandantBekannt: true,
      );

      expect(state.anredeartWeichtAb, isFalse);
    });

    test('eine abweichende Wahl sagt, dass die Stammdaten bleiben', () {
      const state = EmailEntwurfState(
        mandantAnrede: Anrede.herr,
        anredeGeschlecht: Anrede.frau,
        mandantBekannt: true,
      );

      expect(
        state.anredeartWeichtAb,
        isTrue,
        reason:
            'sonst hielte der Anwalt eine Korrektur für diese Mail für eine '
            'Korrektur im Register',
      );
      expect(
        state.anredeartNachtragbar,
        isFalse,
        reason:
            'eine hinterlegte Anredeart wird im Register korrigiert, nicht '
            'aus dem Versanddialog überschrieben (§1.3)',
      );
      expect(state.geschlecht, Anrede.frau);
    });

    test('eine Lücke im Register lässt sich nachtragen', () {
      const state = EmailEntwurfState(
        mandantAnrede: Anrede.keine,
        anredeGeschlecht: Anrede.frau,
        mandantBekannt: true,
      );

      expect(state.anredeartNachtragbar, isTrue);
      expect(
        state.anredeartWeichtAb,
        isFalse,
        reason: 'es wird nichts übergangen — dort steht ja nichts',
      );
    });

    test('ohne Mandanten gibt es nichts nachzutragen', () {
      const state = EmailEntwurfState(anredeGeschlecht: Anrede.frau);

      expect(
        state.anredeartNachtragbar,
        isFalse,
        reason: 'der Knopf haette kein Ziel',
      );
    });

    test('„keine Angabe" gewählt ist kein Nachtrag', () {
      const state = EmailEntwurfState(
        anredeGeschlecht: Anrede.keine,
        mandantBekannt: true,
      );

      expect(
        state.anredeartNachtragbar,
        isFalse,
        reason: '„keine Angabe" ins Register zu schreiben aendert dort nichts',
      );
    });
  });

  group('die Vorschau der Beugungen im Editor', () {
    test('zeigt alle drei Formen unter den Beschriftungen der Chips', () {
      final zeile = BeugungVorschauZeile.formenText(
        Beugung.aus('Mandant/Mandantin/Mandantschaft')!,
      );

      expect(zeile, contains('Herr: Mandant'));
      expect(zeile, contains('Frau: Mandantin'));
      expect(zeile, contains('Keine Angabe: Mandantschaft'));
    });

    test('markiert nur eine errechnete neutrale Form', () {
      expect(
        BeugungVorschauZeile.formenText(Beugung.aus('Mandant/Mandantin')!),
        contains('Keine Angabe: Mandant(in) (errechnet)'),
        reason:
            'genau das ist der Gewinn der Vorschau — ob „Mandant(in)" so in '
            'der Mail stehen soll, sieht der Anwalt sonst erst spät',
      );
      expect(
        BeugungVorschauZeile.formenText(
          Beugung.aus('Mandant/Mandantin/Mandantschaft')!,
        ),
        isNot(contains('errechnet')),
        reason: 'eine geschriebene Form braucht keinen Hinweis',
      );
    });
  });

  group('Überschrift über den Mängeln im Editor', () {
    test('beugt den Plural', () {
      expect(
        VorlagenMaengelListe.titelFuer(1),
        'Ein Platzhalter liefert nichts',
      );
      expect(
        VorlagenMaengelListe.titelFuer(3),
        '3 Platzhalter liefern nichts',
        reason: '„1 Platzhalter liefern nichts" wäre ein Schnitzer',
      );
    });
  });

  group('Hinweis am von Hand bearbeiteten Text', () {
    test('nennt, was noch wirkt und was nicht', () {
      // Der stille Leerlauf war der Mangel: Die Chips blieben anfassbar und
      // taten nichts. Dieser Satz ist die ganze Auskunft, die fehlte.
      expect(
        HandarbeitHinweis.erklaerung,
        allOf(
          contains('Anrede und Zusatzgruß'),
          contains('Vorlage'),
          contains('Anredeart'),
          contains('neu erzeugen'),
        ),
      );
    });
  });
}
