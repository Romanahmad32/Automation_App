import 'package:automation_app/features/email_versand/domain/services/text_nachtrag.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anrede und Zusatzgruß in einem **von Hand bearbeiteten** Mailtext
/// nachziehen (§4.7).
///
/// Der Fall, der diese Datei trägt: Ab dem ersten eigenen Anschlag im Text
/// hörte die Ableitung auf — richtig, damit die Handarbeit nicht verschwindet.
/// Die Chips darüber blieben aber anfassbar und liefen **still leer**. Was die
/// App zuletzt selbst eingesetzt hat, kennt sie wörtlich; genau diese Stelle
/// darf sie tauschen, und nur sie.
void main() {
  group('ersetzt', () {
    test('tauscht die Anredezeile und lässt den Rest stehen', () {
      const text =
          'Sehr geehrter Herr Müller,\n'
          '\n'
          'ich habe das selbst geschrieben und will es behalten.';

      final neu = TextNachtrag.ersetzt(
        text,
        alt: 'Sehr geehrter Herr Müller',
        neu: 'Sehr geehrte Frau Müller',
      );

      expect(neu, startsWith('Sehr geehrte Frau Müller,'));
      expect(neu, contains('ich habe das selbst geschrieben'));
    });

    test('null, wenn die alte Fassung nicht mehr dasteht', () {
      final neu = TextNachtrag.ersetzt(
        'Hallo Klaus,\n\nselbst umgeschrieben.',
        alt: 'Sehr geehrter Herr Müller',
        neu: 'Sehr geehrte Frau Müller',
      );

      expect(
        neu,
        isNull,
        reason:
            'dann gehört die Stelle dem Anwalt — und null ist die Auskunft '
            '„hier greift die Ersetzung nicht", nicht „der Text ist leer"',
      );
    });

    test('null bei leerer alter Fassung und bei gleichem Text', () {
      expect(TextNachtrag.ersetzt('Text', alt: '', neu: 'X'), isNull);
      expect(TextNachtrag.ersetzt('Text', alt: 'Text', neu: 'Text'), isNull);
    });

    test('nur das erste Vorkommen', () {
      final neu = TextNachtrag.ersetzt(
        'Sehr geehrte Damen und Herren,\n'
        '\n'
        'wie ich Sehr geehrte Damen und Herren schon schrieb …',
        alt: 'Sehr geehrte Damen und Herren',
        neu: 'Sehr geehrter Herr Müller',
      );

      expect(neu, startsWith('Sehr geehrter Herr Müller,'));
      expect(
        neu,
        contains('wie ich Sehr geehrte Damen und Herren schon schrieb'),
        reason: 'weiter unten steht ein Satz, den der Anwalt geschrieben hat',
      );
    });

    test('ohne Ersatz geht die Zusatzgruß-Zeile mit', () {
      // Sonst bliebe ihr Komma allein auf der Zeile stehen — dieselbe Regel
      // wie beim Erzeugen, wo ein leerer Platzhalter seine Zeile mitnimmt.
      final neu = TextNachtrag.ersetzt(
        'Sehr geehrter Herr Müller,\n'
        'Salamu aleikum,\n'
        '\n'
        'in obiger Angelegenheit …',
        alt: 'Salamu aleikum',
        neu: '',
      );

      expect(neu, isNot(contains('Salamu')));
      expect(
        neu,
        'Sehr geehrter Herr Müller,\n\nin obiger Angelegenheit …',
        reason: 'und keine zweite Leerzeile, wo die Zeile stand',
      );
    });

    test('mitten im Satz bleibt die Zeile und verliert nur die Angabe', () {
      final neu = TextNachtrag.ersetzt(
        'Ich grüße Sie mit Salamu aleikum und verbleibe',
        alt: 'Salamu aleikum',
        neu: '',
      );

      expect(neu, 'Ich grüße Sie mit  und verbleibe');
    });
  });

  group('nachgezogen', () {
    test('tauscht beide und meldet die neuen Merker', () {
      final stand = TextNachtrag.nachgezogen(
        'Sehr geehrter Herr Müller,\nSalamu aleikum,\n\nText.',
        alteAnrede: 'Sehr geehrter Herr Müller',
        neueAnrede: 'Guten Tag Frau Müller',
        alterGruss: 'Salamu aleikum',
        neuerGruss: 'Grüß Gott',
      );

      expect(stand.text, startsWith('Guten Tag Frau Müller,\nGrüß Gott,'));
      expect(stand.anrede, 'Guten Tag Frau Müller');
      expect(stand.zusatzgruss, 'Grüß Gott');
    });

    test('beide in derselben Zeile gehen auch', () {
      // Der Grund für **einen** Aufruf statt zweier: Die zweite Ersetzung muss
      // auf dem Ergebnis der ersten arbeiten.
      final stand = TextNachtrag.nachgezogen(
        'Sehr geehrter Herr Müller, Salamu aleikum,',
        alteAnrede: 'Sehr geehrter Herr Müller',
        neueAnrede: 'Sehr geehrte Frau Müller',
        alterGruss: 'Salamu aleikum',
        neuerGruss: 'Grüß Gott',
      );

      expect(stand.text, 'Sehr geehrte Frau Müller, Grüß Gott,');
    });

    test('der Merker zieht nur bei Erfolg mit', () {
      final stand = TextNachtrag.nachgezogen(
        'Hallo Klaus,\n\nganz selbst geschrieben.',
        alteAnrede: 'Sehr geehrter Herr Müller',
        neueAnrede: 'Sehr geehrte Frau Müller',
        alterGruss: '',
        neuerGruss: 'Grüß Gott',
      );

      expect(stand.text, 'Hallo Klaus,\n\nganz selbst geschrieben.');
      expect(
        stand.anrede,
        'Sehr geehrter Herr Müller',
        reason:
            'die Stelle gehört dem Anwalt — der nächste Versuch soll dort '
            'auch nichts mehr suchen',
      );
      expect(
        stand.zusatzgruss,
        isEmpty,
        reason: 'ohne alten Gruß gibt es keine Stelle, an die der neue käme',
      );
    });
  });
}
