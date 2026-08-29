import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/services/versand_voraussetzungen.dart';
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
