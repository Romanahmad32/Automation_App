import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/email_versand/domain/services/versand_voraussetzungen.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was der Mail noch fehlt, je Feld (§4.7). Gesagt wird es beim Druecken auf
/// „Senden" -- der teuerste Fall sieht von aussen vollstaendig aus.
void main() {
  const vollstaendig = EmailEntwurf(
    an: ['schaden@huk.de'],
    betreff: 'Anspruchsschreiben 84/26 C03',
  );

  test('ein vollstaendiger Entwurf hat keine offenen Punkte', () {
    final pruefung = VersandVoraussetzungen.pruefe(entwurf: vollstaendig);

    expect(pruefung.vollstaendig, isTrue);
    expect(pruefung.punkte, isEmpty);
    expect(pruefung.erster, isNull);
  });

  test('nennt fehlenden Empfaenger und Betreff je an ihrem Feld', () {
    final pruefung = VersandVoraussetzungen.pruefe(
      entwurf: const EmailEntwurf(),
    );

    expect(pruefung.anFehler, contains('Empfänger'));
    expect(pruefung.betreffFehler, contains('Betreff'));
    expect(pruefung.punkte, hasLength(2));
  });

  test('eine nicht uebernommene Adresse steht an ihrer Zeile', () {
    // Der Fall aus dem Test in der Kanzlei: Das Feld sieht ausgefuellt aus,
    // der Entwurf hat aber keinen Empfaenger. Er gehoert an genau diese Zeile
    // -- ein Kasten oben im Dialog laesst offen, welche der beiden gemeint ist.
    final pruefung = VersandVoraussetzungen.pruefe(
      entwurf: const EmailEntwurf(betreff: 'Anspruchsschreiben'),
      offenAn: 'schaden@huk.de',
    );

    expect(pruefung.anFehler, contains('schaden@huk.de'));
    expect(pruefung.anFehler, contains('noch nicht übernommen'));
    expect(pruefung.erster, pruefung.anFehler);
  });

  test('eine offene Kopie-Adresse haelt den Versand ebenfalls auf', () {
    // Sie ginge sonst still verloren: Der Entwurf sieht vollstaendig aus, und
    // der Empfaenger in Kopie bekommt die Mail nie.
    final pruefung = VersandVoraussetzungen.pruefe(
      entwurf: vollstaendig,
      offenKopie: 'mandant@example.de',
    );

    expect(pruefung.vollstaendig, isFalse);
    expect(pruefung.kopieFehler, contains('mandant@example.de'));
    expect(pruefung.anFehler, isNull);
  });

  test('leere Eingaben zaehlen nicht als offener Punkt', () {
    final pruefung = VersandVoraussetzungen.pruefe(
      entwurf: vollstaendig,
      offenAn: '',
      offenKopie: '   ',
    );

    expect(pruefung.vollstaendig, isTrue);
  });

  test('ein Betreff aus Leerzeichen ist keiner', () {
    final pruefung = VersandVoraussetzungen.pruefe(
      entwurf: const EmailEntwurf(an: ['a@b.de'], betreff: '   '),
    );

    expect(pruefung.punkte, hasLength(1));
    expect(pruefung.betreffFehler, isNotNull);
  });

  group('ein offener Platzhalter sperrt den Versand (§4.7)', () {
    // Ergaenzt am 06.09.2026. Bis dahin nahm ein leerer Daten-Platzhalter
    // seine Zeile mit, und die Mail ging ohne sie hinaus -- die Luecke
    // verschwand unbemerkt im fertigen Anschreiben. Jetzt steht er sichtbar
    // als {{...}} im Entwurf, und genau daran haelt diese Pruefung an: Ein
    // sichtbares {{...}} beim Versicherer oder beim Gericht waere schlimmer
    // als eine Mail, die gar nicht erst hinausging (§1.3).

    final vorgang = Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 6, 20),
      laufendeNummer: 84,
      jahr: '26',
      abteilung: 'C03',
      mandantName: 'Klaus Mueller',
    );

    test('nennt Name, Stelle und Grund', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: const EmailEntwurf(
          an: ['schaden@huk.de'],
          betreff: 'Anspruchsschreiben',
          text: 'Guten Tag,\nTelefon: {{MandantTelefon}}',
        ),
        vorgang: vorgang,
      );

      expect(pruefung.vollstaendig, isFalse);
      expect(pruefung.platzhalterFehler, contains('{{MandantTelefon}}'));
      expect(pruefung.platzhalterFehler, contains('in Zeile 2'));
      expect(
        pruefung.platzhalterFehler,
        contains('Mandantenregister'),
        reason:
            'der Grund entscheidet, ob nachzupflegen oder zu berichtigen ist',
      );
    });

    test('ohne gewaehlten Vorgang sagt der Grund genau das', () {
      // Sonst behauptete die Auskunft eine Luecke im Register, wo in Wahrheit
      // die Akte fehlt -- zwei ganz verschiedene Aufgaben.
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: const EmailEntwurf(
          an: ['schaden@huk.de'],
          betreff: 'Anspruchsschreiben',
          text: 'Telefon: {{MandantTelefon}}',
        ),
      );

      expect(pruefung.platzhalterFehler, contains('kein Vorgang gewählt'));
    });

    test('auch im Betreff -- dort ist er am teuersten', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: const EmailEntwurf(
          an: ['schaden@huk.de'],
          betreff: 'Sache {{VersichererName}}',
          text: 'Guten Tag,',
        ),
      );

      expect(pruefung.platzhalterFehler, contains('im Betreff'));
    });

    test('mehrere werden aufgezaehlt, jeder mit seiner Stelle', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: const EmailEntwurf(
          an: ['schaden@huk.de'],
          betreff: 'Sache {{VersichererName}}',
          text: 'Guten Tag,\nUnfallort: {{Unfallort}}',
        ),
      );

      expect(pruefung.platzhalterFehler, startsWith('2 Platzhalter'));
      expect(pruefung.platzhalterFehler, contains('{{VersichererName}}'));
      expect(pruefung.platzhalterFehler, contains('{{Unfallort}}'));
    });

    test('ein fertiger Entwurf ohne {{...}} bleibt unbehelligt', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: const EmailEntwurf(
          an: ['schaden@huk.de'],
          betreff: 'Sache Klaus Mueller',
          text: 'Sehr geehrte Damen und Herren,\n\nanbei das Schreiben.',
        ),
      );

      expect(pruefung.vollstaendig, isTrue);
      expect(pruefung.platzhalterFehler, isNull);
    });

    test('Anrede und Zusatzgruss kommen hier gar nicht erst an', () {
      // Die Ausnahme aus §4.7, und sie ist im Fueller eingeloest: Beide werden
      // im Dialog gewaehlt, und ohne Wahl nimmt ihr Platzhalter seine Zeile
      // mit -- im fertigen Entwurf steht deshalb kein {{Zusatzgruss}} mehr, an
      // dem diese Pruefung anschlagen koennte.
      final gefuellt =
          MailVorlagenFueller(
            anrede: 'Sehr geehrte Damen und Herren',
          ).fuelleVorlage(
            const MailVorlage(
              betreff: 'Anspruchsschreiben',
              text: '{{Anrede}},\n{{Zusatzgruß}},\n\nanbei das Schreiben.',
            ),
          );

      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: EmailEntwurf(
          an: const ['schaden@huk.de'],
          betreff: gefuellt.betreff,
          text: gefuellt.text,
        ),
      );

      expect(gefuellt.text, isNot(contains('{{')));
      expect(pruefung.vollstaendig, isTrue);
    });

    test('der offene Punkt steht hinter dem fehlenden Betreff', () {
      // Die Reihenfolge in `punkte` ist die des Formulars: Wer keinen Betreff
      // hat, soll nicht zuerst ueber einen Platzhalter im Text lesen.
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: const EmailEntwurf(
          an: ['schaden@huk.de'],
          text: '{{Unfallort}}',
        ),
      );

      expect(pruefung.erster, pruefung.betreffFehler);
      expect(pruefung.punkte, hasLength(2));
    });
  });

  group('Groesse der Nachricht', () {
    const zehnMb = 10 * 1024 * 1024;

    test('unter der Grenze ist nichts offen', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: vollstaendig,
        gesamtBytes: zehnMb - 1,
        maxBytes: zehnMb,
      );

      expect(pruefung.vollstaendig, isTrue);
    });

    test('darueber nennt beide Zahlen und was dagegen hilft', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: vollstaendig,
        gesamtBytes: 12 * 1024 * 1024,
        maxBytes: zehnMb,
      );

      expect(pruefung.punkte, hasLength(1));
      expect(pruefung.groesseFehler, contains('12.0 MB'));
      expect(pruefung.groesseFehler, contains('10.0 MB'));
      // Der Ausweg gehoert in dieselbe Zeile: Wer die Grenze reisst, will
      // wissen, was er tun kann -- und die Signatur ist der Posten, an den
      // niemand von selbst denkt.
      expect(pruefung.groesseFehler, contains('Signatur'));
    });

    test('ohne bekannte Grenze wird nicht gemeckert', () {
      final pruefung = VersandVoraussetzungen.pruefe(
        entwurf: vollstaendig,
        gesamtBytes: 500 * 1024 * 1024,
      );

      expect(pruefung.vollstaendig, isTrue);
    });
  });
}
