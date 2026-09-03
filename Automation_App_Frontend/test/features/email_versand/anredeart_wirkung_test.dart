import 'package:automation_app/features/email_versand/domain/entities/anredeart_wirkung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Satz, der sagt, worauf die **Anredeart** gerade wirkt (§4.7).
///
/// Vorher stand dort fest „Beugt die Anrede und die Wortformen im Text" — ein
/// Versprechen, das die häufigste Mail dieser Kanzlei nicht einlöst: An die
/// Versicherung ist die Anrede neutral, und die mitgelieferte Vorlage trägt
/// kein gebeugtes Wort. Der Klick tat sichtbar nichts, und die Reihe behauptete
/// weiter, er täte zweierlei.
///
/// Geprüft wird jede der sechs Lagen, weil jeder Satz genau eine davon
/// beschreibt und ein Satz, der die falsche beschreibt, schlechter ist als
/// keiner.
void main() {
  group('beides, eines, nichts', () {
    test('Anrede und Wörter', () {
      const wirkung = AnredeartWirkung(anredezeile: true, woerter: 3);

      expect(wirkung.wirkt, isTrue);
      expect(
        wirkung.hinweis,
        'Wirkt auf die Anrede und auf 3 gebeugte Wörter '
        'in der Vorlage.',
      );
    });

    test('nur die Anrede — die fehlende Beugung fehlt hier niemandem', () {
      // Sie täte nichts zur Sache: Die Anredeart arbeitet. Es zu melden wäre
      // ein Mangel, der keiner ist.
      const wirkung = AnredeartWirkung(anredezeile: true);

      expect(wirkung.hinweis, 'Wirkt auf die Anrede.');
    });

    test('nur die Wörter, weil die Anrede neutral ist', () {
      const wirkung = AnredeartWirkung(woerter: 2);

      expect(wirkung.wirkt, isTrue);
      expect(
        wirkung.hinweis,
        'Wirkt auf 2 gebeugte Wörter in der Vorlage — die Anrede ist neutral.',
      );
    });

    test('nirgends — und nur hier steht das Muster dazu', () {
      const wirkung = AnredeartWirkung();

      expect(wirkung.wirkt, isFalse);
      expect(wirkung.hinweis, contains('Wirkt gerade nirgends'));
      expect(
        wirkung.hinweis,
        contains('{{Mandant/Mandantin}}'),
        reason:
            'wer eine Wirkung sucht und keine bekommt, soll erfahren, wie '
            'man eine herstellt',
      );
    });
  });

  group('keine Anredezeile ist etwas anderes als eine neutrale', () {
    test('mit Wörtern: die Vorlage hat keine Zeile', () {
      // „Die Anrede ist neutral" wäre hier falsch — es gibt keine. Derselbe
      // Fehler, nur eine Ebene tiefer, als den Grund für die neutrale Anrede
      // an einer Vorlage ohne Anredezeile zu nennen.
      const wirkung = AnredeartWirkung(woerter: 1, ohneAnredezeile: true);

      expect(
        wirkung.hinweis,
        'Wirkt auf ein gebeugtes Wort in der Vorlage — eine Anredezeile hat '
        'sie nicht.',
      );
      expect(wirkung.hinweis, isNot(contains('neutral')));
    });

    test('ohne Wörter: die Vorlage hat gar nichts zu beugen', () {
      const wirkung = AnredeartWirkung(ohneAnredezeile: true);

      expect(
        wirkung.hinweis,
        'Wirkt gerade nirgends: Die Vorlage hat keine Anredezeile und keine '
        'gebeugte Form.',
      );
      expect(wirkung.wirkt, isFalse);
    });
  });

  test('die Zahl beugt den Plural', () {
    expect(
      const AnredeartWirkung(woerter: 1).hinweis,
      contains('ein gebeugtes Wort'),
    );
    expect(
      const AnredeartWirkung(woerter: 4).hinweis,
      contains('4 gebeugte Wörter'),
    );
  });
}
