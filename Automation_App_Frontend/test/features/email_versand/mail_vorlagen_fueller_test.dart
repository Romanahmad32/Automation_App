import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Platzhalter einer Mail-Textvorlage (§4.7).
///
/// Der Fall, der diese Datei trägt: Der Zusatzgruß (§5.1) steht in der Vorlage
/// unter der Anrede — überall, wo `{{Zusatzgruß}}` steht, und ohne gewählten
/// Gruß darf dort keine Lücke bleiben. Was dabei übersprungen wurde, muss
/// auffindbar bleiben: Die entfallene Zeile ist im Ergebnis nicht zu sehen.
void main() {
  Mandant mandantMit(String grussformel) => Mandant(
    id: 7,
    anrede: Anrede.herr,
    vorname: 'Klaus',
    nachname: 'Müller',
    emailAdresse: 'k.mueller@example.de',
    persoenlicheGrussformel: grussformel,
    erstelltAm: DateTime(2026, 1, 1),
  );

  final vorgang = Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 6, 20),
    laufendeNummer: 84,
    jahr: '26',
    abteilung: 'C03',
    mandantName: 'Klaus Müller',
    gegner: 'HUK-COBURG',
    unfallDatum: '12.06.2026',
    antwort: const ZentralrufReplyData(
      versichererName: 'HUK-COBURG',
      versichererEmail: 'schaden@huk.de',
    ),
  );

  const kanzlei = KanzleiSettings(name: 'Rechtsanwalt Max Muster');

  /// Der Füller so, wie der Cubit ihn baut: Die Anrede kommt aus dem
  /// `EmailEntwurfErzeuger`, damit hier dieselbe Regel gilt wie im Dialog.
  /// Der Zusatzgruß geht **ohne** Rücksicht auf die Empfänger mit — genau das
  /// ist die Änderung vom 02.09.2026.
  MailVorlagenFueller fuellerFuer(Mandant mandant, List<String> empfaenger) {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang,
      mandant: mandant,
    );
    return MailVorlagenFueller(
      anrede: erzeuger.anredeFuer(empfaenger),
      // Der gewaehlte Zusatzgruss (§4.7); vorbelegt ist, was am Mandanten
      // steht — so baut ihn auch der Cubit.
      zusatzgruss: mandant.persoenlicheGrussformel,
      vorgang: vorgang,
      mandant: mandant,
    );
  }

  const anschreiben =
      '{{Anrede}},\n'
      '{{Zusatzgruß}},\n'
      '\n'
      'ich bedanke mich höflichst für das mir entgegengebrachte Vertrauen.';

  group('Zusatzgruß', () {
    test('steht unter der Anrede, wenn nur der Mandant angeschrieben wird', () {
      final text = fuellerFuer(mandantMit('Salamu aleikum'), const [
        'k.mueller@example.de',
      ]).fuelleText(anschreiben);

      expect(text, startsWith('Sehr geehrter Herr Müller,\nSalamu aleikum,\n'));
    });

    test('ohne gewählten Gruß entsteht keine Leerzeile', () {
      final text = fuellerFuer(mandantMit(''), const [
        'k.mueller@example.de',
      ]).fuelleText(anschreiben);

      expect(
        text,
        'Sehr geehrter Herr Müller,\n'
        '\n'
        'ich bedanke mich höflichst für das mir entgegengebrachte Vertrauen.',
      );
      expect(text, isNot(contains('\n\n\n')));
    });

    test('geht auch mit, wenn die Versicherung mitliest', () {
      // Geaendert am 02.09.2026: Bis dahin sperrte der Empfaengerkreis den
      // Gruss. Die Vorlagenwahl ist die Entscheidung — wer eine Vorlage mit
      // {{Zusatzgruss}} nimmt, will ihn. Die Anrede bleibt davon unberuehrt:
      // Eine Mail an zwei Empfaenger kann nur eine haben.
      final text = fuellerFuer(mandantMit('Salamu aleikum'), const [
        'k.mueller@example.de',
        'schaden@huk.de',
      ]).fuelleText(anschreiben);

      expect(text, contains('Salamu aleikum'));
      expect(text, startsWith('Sehr geehrte Damen und Herren,\n'));
    });

    test('auch mit ss geschrieben meint der Platzhalter dieselbe Angabe', () {
      final text = fuellerFuer(mandantMit('Sat Sri Akal'), const [
        'k.mueller@example.de',
      ]).fuelleText('{{Zusatzgruss}}');

      expect(text, 'Sat Sri Akal');
    });
  });

  group('die Gegenüberstellung zeigt, was die Mail enthält', () {
    /// Eine Vorlage mit leer bleibender Gruss-Zeile und einer Leerzeile am
    /// Ende — genau die Stellen, an denen `fuelleText` mehr tut als ersetzen.
    const mitLuecke = MailVorlage(
      id: 2,
      name: 'Mit Luecke',
      betreff: 'Zu {{Referenz}}',
      text:
          '{{Anrede}},\n'
          '{{Zusatzgruss}},\n'
          '\n'
          'Text der Mail.\n'
          '\n',
    );

    test('Zeile für Zeile dasselbe wie der gefüllte Text', () {
      // Die Gegenueberstellung rechnete selbst und kannte dabei nur das
      // Ersetzen: nicht das Zusammenziehen doppelter Leerzeilen, nicht das
      // Abschneiden am Ende. Sie zeigte Zeilen, die in der Mail nicht stehen —
      // ausgerechnet im Dialog, dessen Zweck es ist, zu zeigen, was daraus
      // wurde.
      final fueller = fuellerFuer(mandantMit(''), const []);

      final gezeigt = [
        for (final zeile in fueller.gegenueberstellung(mitLuecke))
          if (zeile.nummer > 0 && zeile.ergebnis != null) zeile.ergebnis!,
      ];

      expect(gezeigt.join('\n'), fueller.fuelleText(mitLuecke.text));
    });

    test('die Gruss-Zeile entfällt, ihr Absatzabstand bleibt einer', () {
      final zeilen = fuellerFuer(
        mandantMit(''),
        const [],
      ).gegenueberstellung(mitLuecke);

      expect(zeilen[2].ergebnis, isNull, reason: 'der Gruss fehlt');
      expect(
        zeilen[3].ergebnis,
        '',
        reason: 'eine Leerzeile trennt die Absätze — zwei wären zu viel',
      );
      expect(zeilen[4].ergebnis, 'Text der Mail.');
      expect(
        zeilen[5].ergebnis,
        isNull,
        reason: 'Leerzeilen am Ende gehen mit — die Mail endet mit Text',
      );
      expect(zeilen[6].ergebnis, isNull);
    });
  });

  group('Platzhalter aus dem Vorgang', () {
    test('werden aus derselben Quelle gefüllt wie die Word-Vorlagen', () {
      final gefuellt = fuellerFuer(mandantMit(''), const []).fuelleVorlage(
        const MailVorlage(
          id: 1,
          name: 'Anschreiben',
          betreff: 'Unfall vom {{Unfalldatum}} · {{VersichererName}}',
          text: 'Unser Zeichen: {{Referenz}}',
        ),
      );

      expect(gefuellt.betreff, 'Unfall vom 12.06.2026 · HUK-COBURG');
      expect(gefuellt.text, 'Unser Zeichen: 84/26 C03_GG-XY 123');
    });

    test('eine Zeile, in der jeder Platzhalter leer bleibt, entfällt', () {
      final text = fuellerFuer(mandantMit(''), const []).fuelleText(
        'Erste Zeile\n'
        'Polizei: {{PolizeiVorgangsnummer}}\n'
        'Letzte Zeile',
      );

      expect(text, 'Erste Zeile\nLetzte Zeile');
    });

    test('eine Zeile mit einem gefüllten Platzhalter bleibt stehen', () {
      final text = fuellerFuer(
        mandantMit(''),
        const [],
      ).fuelleText('{{MandantName}} ./. {{PolizeiVorgangsnummer}}');

      expect(text, 'Klaus Müller ./.');
    });

    test('bleibt vom Betreff nichts übrig, bleibt er leer', () {
      final betreff = fuellerFuer(
        mandantMit(''),
        const [],
      ).fuelleBetreff('Vorgang {{PolizeiVorgangsnummer}}');

      expect(
        betreff,
        isEmpty,
        reason: 'eine erfundene Betreffzeile wäre schlimmer',
      );
    });
  });

  group('Befunde: was übersprungen wurde, bleibt auffindbar (§4.7)', () {
    /// Die Vorlage aus dem Ausgangsbestand, verkürzt: Der Zusatzgruß steht in
    /// Zeile 2, und ohne Wahl nimmt er sie mit.
    const vorlage = MailVorlage(
      id: 1,
      name: 'Anschreiben',
      betreff: 'Ihre Sache {{MandantName}} · {{PolizeiVorgangsnummer}}',
      text:
          '{{Anrede}},\n'
          '{{Zusatzgruß}},\n'
          '\n'
          'Unser Zeichen: {{Referenz}}',
    );

    test('ein leerer Befund nennt seine Zeile und dass sie entfällt', () {
      final befunde = fuellerFuer(mandantMit(''), const [
        'k.mueller@example.de',
      ]).befunde(vorlage);

      final gruss = befunde.firstWhere((befund) => befund.name == 'Zusatzgruß');
      expect(gruss.istLeer, isTrue);
      expect(gruss.zeile, 2, reason: 'die zweite Zeile des Nachrichtentexts');
      expect(gruss.imBetreff, isFalse);
      expect(gruss.zeileEntfaellt, isTrue);
      expect(gruss.folge, 'bleibt leer — Zeile 2 entfällt');
    });

    test('ein leerer Platzhalter im Betreff sagt das statt einer Zeile', () {
      final befunde = fuellerFuer(mandantMit(''), const []).befunde(vorlage);

      final polizei = befunde.firstWhere(
        (befund) => befund.name == 'PolizeiVorgangsnummer',
      );
      expect(polizei.imBetreff, isTrue);
      expect(polizei.zeile, 0);
      expect(
        polizei.zeileEntfaellt,
        isFalse,
        reason: '{{MandantName}} haelt die Betreffzeile am Leben',
      );
      expect(polizei.folge, 'bleibt leer — fällt aus dem Betreff');
    });

    test('ein gefüllter Befund nennt seine Herkunft und bleibt ohne Folge', () {
      final befunde = fuellerFuer(mandantMit('Sat Sri Akal'), const [
        'k.mueller@example.de',
      ]).befunde(vorlage);

      final gruss = befunde.firstWhere((befund) => befund.name == 'Zusatzgruß');
      expect(gruss.wert, 'Sat Sri Akal');
      expect(gruss.herkunft, 'beim Verfassen gewählt');
      expect(gruss.folge, isEmpty);
      expect(gruss.zeileEntfaellt, isFalse);
    });

    test('jeder Name steht nur einmal, in der Reihenfolge des Auftretens', () {
      final befunde = fuellerFuer(mandantMit(''), const []).befunde(
        const MailVorlage(
          id: 2,
          name: 'Doppelt',
          betreff: '{{MandantName}}',
          text: 'Zeile eins {{Referenz}}\n{{MandantName}} noch einmal',
        ),
      );

      expect(
        befunde.map((befund) => befund.name),
        ['MandantName', 'Referenz'],
        reason: 'der Betreff zaehlt zuerst, Dubletten entfallen',
      );
      expect(befunde.first.zeile, 0, reason: 'aus dem Betreff');
      expect(befunde.last.zeile, 1);
    });
  });

  group('die Beugung folgt der gewählten Anredeart (§4.7)', () {
    /// Der Füller mit einer je Mail gewählten Anredeart — so baut ihn
    /// `EntwurfAbleitung`: Die Anredezeile und die Wortformen im Text ziehen
    /// beide aus **derselben** Angabe, damit sie nicht auseinanderlaufen.
    MailVorlagenFueller mitAnredeart(
      Anrede geschlecht, {
      List<String> empfaenger = const [],
    }) {
      final mandant = mandantMit('');
      final erzeuger = EmailEntwurfErzeuger(
        kanzlei: kanzlei,
        vorgang: vorgang,
        mandant: mandant,
      );
      return MailVorlagenFueller(
        anrede: erzeuger.anredeFuer(empfaenger, geschlecht: geschlecht),
        geschlecht: erzeuger.geschlechtFuer(geschlecht),
        vorgang: vorgang,
        mandant: mandant,
      );
    }

    const mitBeugung =
        'in der Schadensache vertrete ich {{Mandant/Mandantin}} '
        '{{MandantName}}.\n'
        'Als {{Geschädigter/Geschädigte}} hat {{er/sie}} Anspruch.';

    test('weiblich setzt überall die weibliche Form', () {
      final text = mitAnredeart(Anrede.frau).fuelleText(mitBeugung);

      expect(text, contains('vertrete ich Mandantin Klaus Müller.'));
      expect(text, contains('Als Geschädigte hat sie Anspruch.'));
    });

    test('männlich setzt überall die männliche Form', () {
      final text = mitAnredeart(Anrede.herr).fuelleText(mitBeugung);

      expect(text, contains('vertrete ich Mandant Klaus Müller.'));
      expect(text, contains('Als Geschädigter hat er Anspruch.'));
    });

    test('ohne Angabe gilt die errechnete neutrale Form', () {
      final text = mitAnredeart(Anrede.keine).fuelleText(mitBeugung);

      expect(
        text,
        contains('Als Geschädigte(r) hat er/sie Anspruch.'),
        reason:
            'gemeinsamer Wortstamm in Klammern, sonst beide mit Schrägstrich '
            '— nie falsch gebeugt, und wo es geht in der kurzen Schreibweise '
            '(geändert am 02.09.2026 auf ausdrücklichen Auftrag)',
      );
    });

    test('die Beugung gilt auch im Betreff', () {
      final betreff = mitAnredeart(
        Anrede.frau,
      ).fuelleBetreff('Ansprüche {{unseres/unserer}} {{Mandant/Mandantin}}');

      expect(betreff, 'Ansprüche unserer Mandantin');
    });

    test('die Beugung hängt am Mandanten, nicht am Empfängerkreis', () {
      // Der häufigste Fall überhaupt: Die Mail geht an die Versicherung,
      // beginnt darum neutral — und schreibt im Text trotzdem von „unserer
      // Mandantin". Genau deshalb sind Anredeart und „neutral anreden" zwei
      // getrennte Angaben.
      final fueller = mitAnredeart(
        Anrede.frau,
        empfaenger: const ['schaden@huk.de'],
      );

      final text = fueller.fuelleText(
        '{{Anrede}},\n\n{{unser/unsere}} {{Mandant/Mandantin}} macht '
        'Ansprüche geltend.',
      );

      expect(text, contains('Sehr geehrte Damen und Herren,'));
      expect(text, contains('unsere Mandantin macht Ansprüche geltend.'));
    });

    test('ein Befund nennt Beugung als Herkunft', () {
      final befunde = mitAnredeart(Anrede.frau).befunde(
        const MailVorlage(
          id: 3,
          name: 'Gebeugt',
          text: '{{Mandant/Mandantin}} meldet sich.',
        ),
      );

      final befund = befunde.single;
      expect(befund.wert, 'Mandantin');
      expect(befund.herkunft, 'nach der gewählten Anredeart');
      expect(befund.bezeichnung, 'Beugung nach der Anredeart');
    });

    test('eine unvollständige Beugung wird erklärt, nicht verschwiegen', () {
      // Vor dieser Schreibweise verlor `{{Mandant/}}` seine Zeile
      // stillschweigend: Der Schrägstrich fällt beim Normalisieren weg, und
      // „mandant" traf keine Datenquelle. Jetzt steht der Grund daneben.
      final befunde = mitAnredeart(Anrede.frau).befunde(
        const MailVorlage(
          id: 4,
          name: 'Halb',
          text: '{{Mandant/}} meldet sich.',
        ),
      );

      final befund = befunde.single;
      expect(befund.istLeer, isTrue);
      expect(befund.zeileEntfaellt, isTrue);
      expect(befund.fehlstelle, contains('Beugung unvollständig'));
      expect(
        befund.fehlstelle,
        contains('{{Mandant/Mandantin}}'),
        reason: 'die Erklärung nennt die Schreibweise, die gemeint war',
      );
    });
  });

  group('der Betreff rechnet je Abschnitt (§4.7)', () {
    /// Ein Vorgang ohne Versicherer — die häufige Lage, solange der Zentralruf
    /// noch nicht geantwortet hat.
    final ohneVersicherer = Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 6, 20),
      laufendeNummer: 84,
      jahr: '26',
      abteilung: 'C03',
      mandantName: 'Klaus Müller',
    );

    MailVorlagenFueller fuellerOhne() => MailVorlagenFueller(
      anrede: 'Sehr geehrter Herr Müller',
      vorgang: ohneVersicherer,
      mandant: mandantMit(''),
    );

    test('ein leerer Abschnitt nimmt sein Trennzeichen mit', () {
      // Der behobene Fehler: Die Zeilenregel liess eine Zeile schon bei
      // **einem** gefüllten Platzhalter stehen. Im Betreff gibt es keine
      // Nachbarzeile, die den Satz weiterträgt — hinaus ging wörtlich
      // „Sache Klaus Müller ./. · Gruß:".
      final betreff = fuellerOhne().fuelleBetreff(
        'Sache {{MandantName}} ./. {{VersichererName}} · Gruß: {{Zusatzgruß}}',
      );

      expect(betreff, 'Sache Klaus Müller');
      expect(betreff, isNot(contains('·')));
      expect(betreff, isNot(endsWith(':')));
    });

    test('bleibt nichts übrig, bleibt der Betreff leer', () {
      expect(
        fuellerOhne().fuelleBetreff('Zeichen: {{VersichererName}}'),
        isEmpty,
        reason:
            'eine erfundene Betreffzeile wäre schlimmer als ein leeres Feld',
      );
    });

    test('ein Betreff ohne Platzhalter bleibt unberührt', () {
      // Vorher lief die Glättung auch über einen von Hand getippten Betreff
      // und zog dessen Leerzeichen zusammen.
      const getippt = 'Rückfrage:  zwei Leerzeichen sind gewollt';
      expect(fuellerOhne().fuelleBetreff(getippt), getippt);
    });
  });

  group('ein Name, aber alle seine Stellen (§4.7)', () {
    test('die zweite entfallene Zeile steht in der Auskunft', () {
      // Der behobene Fehler: `befunde` entdoppelte über Betreff **und** Text.
      // Gemeldet wurde nur „fällt aus dem Betreff"; dass Zeile 2 ebenfalls
      // ersatzlos wegfiel, stand nirgends — und im gefüllten Text ist davon
      // nichts mehr zu sehen.
      final befunde =
          fuellerFuer(mandantMit(''), const ['k.mueller@example.de']).befunde(
            const MailVorlage(
              name: 'Probe',
              betreff: 'Zeichen: {{Zusatzgruß}}',
              text: 'Hallo\nGruß: {{Zusatzgruß}}',
            ),
          );

      final gruss = befunde.singleWhere((b) => b.name == 'Zusatzgruß');
      expect(gruss.imBetreff, isTrue);
      expect(gruss.zeileEntfaellt, isTrue);
      expect(gruss.weitereEntfallene, const [2]);
      expect(
        gruss.folge,
        'bleibt leer — fällt aus dem Betreff, Zeile 2 entfällt',
      );
    });

    test('ein Name in nur einer Zeile bleibt schlicht', () {
      final befunde =
          fuellerFuer(mandantMit(''), const ['k.mueller@example.de']).befunde(
            const MailVorlage(
              name: 'Probe',
              betreff: '',
              text: '{{Zusatzgruß}}',
            ),
          );

      expect(befunde.single.weitereEntfallene, isEmpty);
      expect(befunde.single.folge, 'bleibt leer — Zeile 1 entfällt');
    });
  });

  group('ein Platzhalter endet an der Zeile (§4.7)', () {
    test('über zwei Zeilen gebrochen ist er keiner', () {
      // Der behobene Fehler: `muster` schloss den Zeilenumbruch ein. Wer den
      // **ganzen** Text absuchte, fand den Platzhalter; wer zeilenweise
      // füllte, fand ihn nie — der Dialog gab die Anredereihe frei, und die
      // Mail ging ohne Anrede hinaus.
      expect(MailPlatzhalter.stehtIn('{{Anrede\n}}', 'Anrede'), isFalse);
      expect(MailPlatzhalter.namenIn('Hallo\n{{An\nrede}}'), isEmpty);
      expect(MailPlatzhalter.stehtIn('{{ Anrede }}', 'Anrede'), isTrue);
    });

    test('und bleibt deshalb auch beim Füllen stehen, wie er ist', () {
      final text = fuellerFuer(mandantMit(''), const [
        'k.mueller@example.de',
      ]).fuelleText('{{Anrede\n}}');

      expect(text, '{{Anrede\n}}');
    });
  });
}
