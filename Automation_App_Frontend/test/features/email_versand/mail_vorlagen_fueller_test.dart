import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Platzhalter einer Mail-Textvorlage (§4.7).
///
/// Der Fall, der diese Datei trägt: Der persönliche Gruß des Mandanten (§5.1)
/// steht in der Vorlage unter der Anrede — aber nur, wenn ausschliesslich er
/// angeschrieben wird, und ohne hinterlegten Gruß darf dort keine Lücke
/// bleiben.
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

  /// Der Füller so, wie der Cubit ihn baut: Anrede und Empfängerkreis kommen
  /// aus dem `EmailEntwurfErzeuger`, damit hier dieselbe Regel gilt wie im
  /// Dialog.
  MailVorlagenFueller fuellerFuer(Mandant mandant, List<String> empfaenger) {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: kanzlei,
      vorgang: vorgang,
      mandant: mandant,
    );
    return MailVorlagenFueller(
      anrede: erzeuger.anredeFuer(empfaenger),
      nurAnDenMandanten: erzeuger.nurAnDenMandanten(empfaenger),
      // Der gewaehlte Zusatzgruss (§4.7); vorbelegt ist, was am Mandanten
      // steht — so baut ihn auch der Cubit.
      grussformel: mandant.persoenlicheGrussformel,
      vorgang: vorgang,
      mandant: mandant,
    );
  }

  const anschreiben =
      '{{Anrede}},\n'
      '{{Grussformel}},\n'
      '\n'
      'ich bedanke mich höflichst für das mir entgegengebrachte Vertrauen.';

  group('persönliche Grußformel', () {
    test('steht unter der Anrede, wenn nur der Mandant angeschrieben wird', () {
      final text = fuellerFuer(mandantMit('Salamu aleikum'), const [
        'k.mueller@example.de',
      ]).fuelleText(anschreiben);

      expect(text, startsWith('Sehr geehrter Herr Müller,\nSalamu aleikum,\n'));
    });

    test('ohne hinterlegte Formel entsteht keine Leerzeile', () {
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

    test('geht nie mit, sobald die Versicherung mitliest', () {
      final text = fuellerFuer(mandantMit('Salamu aleikum'), const [
        'k.mueller@example.de',
        'schaden@huk.de',
      ]).fuelleText(anschreiben);

      expect(text, isNot(contains('Salamu aleikum')));
      expect(text, startsWith('Sehr geehrte Damen und Herren,\n'));
    });

    test('auch mit ß geschrieben meint der Platzhalter dieselbe Angabe', () {
      final text = fuellerFuer(mandantMit('Sat Sri Akal'), const [
        'k.mueller@example.de',
      ]).fuelleText('{{Grußformel}}');

      expect(text, 'Sat Sri Akal');
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
}
