import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/services/versand_voraussetzungen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Warum „Senden" grau bleibt (§4.7). Der Knopf allein sagt es nicht, und der
/// teuerste Fall sieht von aussen vollstaendig aus.
void main() {
  const vollstaendig = EmailEntwurf(
    an: ['schaden@huk.de'],
    betreff: 'Anspruchsschreiben 84/26 C03',
  );

  test('ein vollstaendiger Entwurf hat keine offenen Punkte', () {
    expect(VersandVoraussetzungen.fehlend(entwurf: vollstaendig), isEmpty);
  });

  test('nennt fehlenden Empfaenger und Betreff', () {
    final fehlt = VersandVoraussetzungen.fehlend(entwurf: const EmailEntwurf());

    expect(fehlt, hasLength(2));
    expect(fehlt.first, contains('Empfänger'));
    expect(fehlt.last, contains('Betreff'));
  });

  test('eine nicht uebernommene Adresse steht zuerst', () {
    // Der Fall aus dem Test in der Kanzlei: Das Feld sieht ausgefuellt aus,
    // der Entwurf hat aber keinen Empfaenger. Ohne diesen Satz erklaert nichts
    // auf dem Schirm den Unterschied.
    final fehlt = VersandVoraussetzungen.fehlend(
      entwurf: const EmailEntwurf(betreff: 'Anspruchsschreiben'),
      offeneEingaben: const ['schaden@huk.de'],
    );

    expect(fehlt.first, contains('schaden@huk.de'));
    expect(fehlt.first, contains('noch nicht übernommen'));
  });

  test('leere Eingaben zaehlen nicht als offener Punkt', () {
    expect(
      VersandVoraussetzungen.fehlend(
        entwurf: vollstaendig,
        offeneEingaben: const ['', '   '],
      ),
      isEmpty,
    );
  });

  test('ein Betreff aus Leerzeichen ist keiner', () {
    final fehlt = VersandVoraussetzungen.fehlend(
      entwurf: const EmailEntwurf(an: ['a@b.de'], betreff: '   '),
    );

    expect(fehlt, ['ein Betreff']);
  });

  group('Groesse der Nachricht', () {
    const zehnMb = 10 * 1024 * 1024;

    test('unter der Grenze ist nichts offen', () {
      expect(
        VersandVoraussetzungen.fehlend(
          entwurf: vollstaendig,
          gesamtBytes: zehnMb - 1,
          maxBytes: zehnMb,
        ),
        isEmpty,
      );
    });

    test('darueber nennt beide Zahlen und was dagegen hilft', () {
      final offen = VersandVoraussetzungen.fehlend(
        entwurf: vollstaendig,
        gesamtBytes: 12 * 1024 * 1024,
        maxBytes: zehnMb,
      );

      expect(offen, hasLength(1));
      expect(offen.single, contains('12.0 MB'));
      expect(offen.single, contains('10.0 MB'));
      // Der Ausweg gehoert in dieselbe Zeile: Wer die Grenze reisst, will
      // wissen, was er tun kann -- und die Signatur ist der Posten, an den
      // niemand von selbst denkt.
      expect(offen.single, contains('Signatur'));
    });

    test('ohne bekannte Grenze wird nicht gemeckert', () {
      expect(
        VersandVoraussetzungen.fehlend(
          entwurf: vollstaendig,
          gesamtBytes: 500 * 1024 * 1024,
        ),
        isEmpty,
      );
    });
  });
}
