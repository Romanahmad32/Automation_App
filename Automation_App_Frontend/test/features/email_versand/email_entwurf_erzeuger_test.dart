import 'package:automation_app/features/email_versand/domain/entities/empfaenger_art.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Vorbelegung des Mail-Entwurfs (§4.7): Der Anwalt soll den Anfang
/// vorfinden, nicht abtippen — und die Anrede muss zum Empfängerkreis passen.
void main() {
  final mandant = Mandant(
    id: 7,
    anrede: Anrede.herr,
    vorname: 'Klaus',
    nachname: 'Müller',
    emailAdresse: 'k.mueller@example.de',
    erstelltAm: DateTime(2026, 1, 1),
  );

  const kanzlei = KanzleiSettings(name: 'Rechtsanwalt Max Muster');

  Vorgang vorgang({String? versichererEmail, String? versichererName}) =>
      Vorgang(
        referenz: '84/26 C03_GG-XY 123',
        angefragtAm: DateTime(2026, 6, 20),
        laufendeNummer: 84,
        jahr: '26',
        abteilung: 'C03',
        mandantName: 'Klaus Müller',
        gegner: 'HUK-COBURG',
        unfallDatum: '12.06.2026',
        antwort: ZentralrufReplyData(
          versichererName: versichererName ?? 'HUK-COBURG',
          versichererEmail: versichererEmail,
          versicherungsscheinNr: '1234567',
        ),
      );

  test('schlägt Mandant und Versicherung aus dem Vorgang vor', () {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(versichererEmail: 'schaden@huk.de'),
      mandant: mandant,
    );

    final vorschlaege = erzeuger.vorschlaege;

    expect(vorschlaege.map((v) => v.adresse), [
      'k.mueller@example.de',
      'schaden@huk.de',
    ]);
    expect(vorschlaege.first.art, EmpfaengerArt.mandant);
    expect(vorschlaege.last.art, EmpfaengerArt.versicherung);
    expect(vorschlaege.last.herkunft, contains('Zentralruf'));
  });

  test('füllt die fehlende Versichereradresse aus dem Register (§5.2)', () {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      mandant: mandant,
      versicherer: const [
        Versicherer(id: 1, name: 'HUK-COBURG', email: 'post@huk.de'),
      ],
    );

    final versicherung = erzeuger.vorschlaege.last;

    expect(versicherung.adresse, 'post@huk.de');
    expect(versicherung.herkunft, contains('früheren Antworten'));
  });

  test('der genaue Registername schlägt jeden Teiltreffer', () {
    // Das Register füllt das Backend selbsttätig aus jeder geparsten Antwort.
    // Steht der gesuchte Name genau darin, darf kein längerer Eintrag, der ihn
    // nur enthält, die Adresse stellen — das Anspruchsschreiben ginge sonst an
    // eine fremde Abteilung.
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      versicherer: const [
        Versicherer(
          id: 1,
          name: 'HUK-COBURG Allgemeine Versicherung AG',
          email: 'allgemeine@huk.de',
        ),
        Versicherer(id: 2, name: 'HUK-COBURG', email: 'post@huk.de'),
      ],
    );

    expect(erzeuger.vorschlaege.single.adresse, 'post@huk.de');
  });

  test('unter Teiltreffern gewinnt der längste, nicht der erste', () {
    // Ohne Rangfolge entschied die Reihenfolge der Liste — also der Zufall.
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(
        versichererName: 'HUK-COBURG Allgemeine Versicherung AG',
      ),
      versicherer: const [
        Versicherer(id: 1, name: 'HUK', email: 'zentrale@huk.de'),
        Versicherer(
          id: 2,
          name: 'HUK-COBURG Allgemeine',
          email: 'allgemeine@huk.de',
        ),
      ],
    );

    expect(erzeuger.vorschlaege.single.adresse, 'allgemeine@huk.de');
  });

  test('Registereinträge ohne Adresse zählen nicht als Treffer', () {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      versicherer: const [
        Versicherer(id: 1, name: 'HUK-COBURG'),
        Versicherer(id: 2, name: 'HUK-COBURG Allgemeine', email: 'a@huk.de'),
      ],
    );

    expect(erzeuger.vorschlaege.single.adresse, 'a@huk.de');
  });

  test('nutzt auch eine noch nicht übernommene Antwort (Postfach)', () {
    // Im Postfach liegt der Treffer vor, die Übernahme in den Vorgang ist der
    // bestätigte Schritt danach (§4.3). Ohne diesen Weg fehlte dort genau die
    // Adresse, die der Anwalt gerade vor sich hat.
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: Vorgang(
        referenz: '84/26 C03_GG-XY 123',
        angefragtAm: DateTime(2026, 6, 20),
        mandantId: 7,
      ),
      mandant: mandant,
      antwort: const ZentralrufReplyData(
        versichererName: 'HUK-COBURG',
        versichererEmail: 'schaden@huk.de',
        unfallDatum: '12.06.2026',
      ),
    );

    expect(erzeuger.vorschlaege.map((v) => v.adresse), [
      'k.mueller@example.de',
      'schaden@huk.de',
    ]);
    expect(
      erzeuger.betreffFuer(mitSchreiben: false),
      contains('Unfall vom 12.06.2026'),
    );
  });

  test('nennt keine Adresse doppelt', () {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(versichererEmail: 'K.Mueller@example.de'),
      mandant: mandant,
    );

    expect(erzeuger.vorschlaege, hasLength(1));
  });

  test('spricht den Mandanten persönlich an, wenn nur er die Mail bekommt', () {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(versichererEmail: 'schaden@huk.de'),
      mandant: mandant,
    );

    expect(
      erzeuger.anredeFuer(['k.mueller@example.de']),
      'Sehr geehrter Herr Müller',
    );
  });

  test('bleibt neutral, sobald die Versicherung mitliest', () {
    // Eine Mail an zwei Empfänger kann nur eine Anrede haben — und „Sehr
    // geehrter Herr Müller" an die Gegenseite wäre ein Fehlgriff.
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(versichererEmail: 'schaden@huk.de'),
      mandant: mandant,
    );

    expect(
      erzeuger.anredeFuer(['k.mueller@example.de', 'schaden@huk.de']),
      'Sehr geehrte Damen und Herren',
    );
  });

  test('Betreff trägt Parteien, Unfalldatum und Aktenzeichen', () {
    final betreff = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      mandant: mandant,
    ).betreffFuer(mitSchreiben: true);

    expect(betreff, startsWith('Anspruchsschreiben'));
    expect(betreff, contains('Klaus Müller ./. HUK-COBURG'));
    expect(betreff, contains('Unfall vom 12.06.2026'));
    expect(betreff, contains('84/26 C03'));
  });

  test('ohne Anhang kündigt der Betreff kein Anspruchsschreiben an', () {
    // Aus dem Postfach heraus wird auch mal nur eine Nachfrage geschrieben.
    final betreff = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      mandant: mandant,
    ).betreffFuer(mitSchreiben: false);

    expect(betreff, isNot(contains('Anspruchsschreiben')));
    expect(betreff, contains('Klaus Müller ./. HUK-COBURG'));
  });

  test('Text nennt den Bezug und endet mit der Kanzlei', () {
    final text = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      mandant: mandant,
    ).textFuer(const ['schaden@huk.de'], mitSchreiben: true);

    expect(text, startsWith('Sehr geehrte Damen und Herren,'));
    expect(text, contains('Versicherungsschein-Nr. 1234567'));
    expect(text, contains('Anspruchsschreiben'));
    expect(text, endsWith('Rechtsanwalt Max Muster'));
  });

  test('ohne Anhang bleibt der Bezugssatz weg', () {
    // „übersende ich Ihnen anbei das Anspruchsschreiben" ohne Anhang wäre
    // schlicht falsch.
    final text = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      mandant: mandant,
    ).textFuer(const ['schaden@huk.de'], mitSchreiben: false);

    expect(text, startsWith('Sehr geehrte Damen und Herren,'));
    expect(text, isNot(contains('übersende')));
    expect(text, endsWith('Rechtsanwalt Max Muster'));
  });

  test('ohne Vorgang und ohne Anhang entsteht ein leeres Anschreiben', () {
    // Der Einstieg aus dem Postfach: Anrede und Gruß stehen, den Rest
    // schreibt der Anwalt. Ein erfundener Betreff wäre schlimmer als keiner.
    final entwurf = const EmailEntwurfErzeuger(
      kanzlei: kanzlei,
    ).entwurfMit(const []);

    expect(entwurf.an, isEmpty);
    expect(entwurf.betreff, isEmpty);
    expect(entwurf.text, startsWith('Sehr geehrte Damen und Herren,'));
    expect(entwurf.text, isNot(contains('Anspruchsschreiben')));
    expect(entwurf.istSendbar, isFalse);
  });

  test('entwurfMit leitet aus den Anhängen ab, dass ein Schreiben mitgeht', () {
    final entwurf = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang(),
      mandant: mandant,
    ).entwurfMit(const ['C:/Akte/Anspruchsschreiben.pdf']);

    expect(entwurf.betreff, startsWith('Anspruchsschreiben'));
    expect(entwurf.text, contains('übersende ich Ihnen anbei'));
    expect(entwurf.anhangPfade, ['C:/Akte/Anspruchsschreiben.pdf']);
  });
}
