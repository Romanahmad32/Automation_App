import 'package:automation_app/features/email_versand/domain/entities/beugung.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Beugung eines Wortes im Vorlagentext (§4.7): `{{Mandant/Mandantin}}`.
///
/// Der Schrägstrich ist die einzige Regel, die der Anwalt lernen muss — was
/// hier steht, ist deshalb das Versprechen, das die Schreibweise gibt.
void main() {
  group('Beugung.aus', () {
    test('zwei Formen ergeben männlich und weiblich', () {
      final beugung = Beugung.aus('Mandant/Mandantin')!;

      expect(beugung.maennlich, 'Mandant');
      expect(beugung.weiblich, 'Mandantin');
    });

    test('ohne dritte Form kommt der Unterschied in Klammern', () {
      // Geändert am 02.09.2026 auf ausdrücklichen Auftrag: Bis dahin stand
      // hier „Geschädigter/Geschädigte" — nie falsch gebeugt, aber hölzern.
      // Das Rechtsdeutsch wiederholt den gemeinsamen Wortstamm nicht.
      expect(
        Beugung.aus('Geschädigter/Geschädigte')!.neutral,
        'Geschädigte(r)',
      );
      expect(Beugung.aus('Mandant/Mandantin')!.neutral, 'Mandant(in)');
      expect(Beugung.aus('Kläger/Klägerin')!.neutral, 'Kläger(in)');
    });

    test('ohne gemeinsamen Stamm bleiben es beide mit Schrägstrich', () {
      // Hier wäre eine Klammer Unsinn: „d(er/ie)". Die Regel greift nur, wo
      // sie nachweislich hinkommt, und sonst gilt der Rückfall, der immer
      // geht — das war die Zusage von Anfang an.
      expect(Beugung.aus('der/die')!.neutral, 'der/die');
      expect(Beugung.aus('er/sie')!.neutral, 'er/sie');
      expect(Beugung.aus('sein/ihr')!.neutral, 'sein/ihr');
      expect(
        Beugung.aus('Zeuge/Zeugin')!.neutral,
        'Zeuge/Zeugin',
        reason: '„Zeug(e/in)" wäre die Cleverness, die danebengreift',
      );
    });

    test('gleiche Formen stehen einmal da', () {
      expect(Beugung.aus('Rechtsanwalt/Rechtsanwalt')!.neutral, 'Rechtsanwalt');
    });

    test('eine errechnete Form ist als solche erkennbar', () {
      expect(
        Beugung.aus('Mandant/Mandantin')!.neutralGeschrieben,
        isFalse,
        reason: 'nur eine errechnete Form kann der Anwalt noch verbessern',
      );
      expect(
        Beugung.aus('Mandant/Mandantin/Mandantschaft')!.neutralGeschrieben,
        isTrue,
      );
    });

    test('die dritte Form schlägt den Rückfall', () {
      final beugung = Beugung.aus('Mandant/Mandantin/Mandantschaft')!;

      expect(beugung.neutral, 'Mandantschaft');
    });

    test('Zwischenräume um die Formen zählen nicht mit', () {
      final beugung = Beugung.aus(' Mandant / Mandantin ')!;

      expect(beugung.maennlich, 'Mandant');
      expect(beugung.weiblich, 'Mandantin');
      expect(
        beugung.neutral,
        'Mandant(in)',
        reason: 'der Rückfall wird aus den getrimmten Formen gebaut',
      );
    });

    test('ohne Schrägstrich ist es keine Beugung', () {
      expect(Beugung.aus('MandantName'), isNull);
    });

    test('eine leere Form ergibt keine Beugung', () {
      expect(Beugung.aus('Mandant/'), isNull);
      expect(Beugung.aus('/Mandantin'), isNull);
      expect(Beugung.aus('Mandant//Mandantschaft'), isNull);
    });

    test('mehr als drei Formen ergeben keine Beugung', () {
      expect(
        Beugung.aus('a/b/c/d'),
        isNull,
        reason:
            'drei Anredearten, drei Formen — eine vierte hätte keine Zuordnung '
            'und wäre ein stiller Tippfehler',
      );
    });
  });

  group('Beugung.istGemeint', () {
    test(
      'erkennt die Absicht am Schrägstrich, auch bei misslungenen Formen',
      () {
        expect(Beugung.istGemeint('Mandant/Mandantin'), isTrue);
        expect(
          Beugung.istGemeint('Mandant/'),
          isTrue,
          reason:
              'sonst fiele der Fall auf die Namenserkennung zurück und bekäme '
              'dort die Auskunft „kein Feld dieses Namens", die am Fehler '
              'vorbeigeht',
        );
      },
    );

    test('ein gewöhnlicher Platzhaltername ist keine', () {
      expect(Beugung.istGemeint('Zusatzgruß'), isFalse);
      expect(Beugung.istGemeint('VersichererAnschrift'), isFalse);
    });
  });

  group('Beugung.formFuer', () {
    final beugung = Beugung.aus('Mandant/Mandantin/Mandantschaft')!;

    test('folgt der Anredeart', () {
      expect(beugung.formFuer(Anrede.herr), 'Mandant');
      expect(beugung.formFuer(Anrede.frau), 'Mandantin');
    });

    test('ohne Angabe gilt die neutrale Form — geraten wird nicht', () {
      expect(beugung.formFuer(Anrede.keine), 'Mandantschaft');
    });
  });

  test('geschrieben zeigt die Schreibweise für die Auswahl im Editor', () {
    expect(Beugung.aus('er/sie')!.geschrieben, '{{er/sie}}');
  });

  test('mit dritter Form steht sie auch in der Schreibweise', () {
    // Sonst nennt die Vorschau einen Platzhalter, der so nicht im Text steht:
    // Wer danach sucht, findet nichts, und es sieht aus, als sei die dritte
    // Form uebergangen worden.
    expect(
      Beugung.aus('Mandant/Mandantin/Mandantschaft')!.geschrieben,
      '{{Mandant/Mandantin/Mandantschaft}}',
    );
  });
}
