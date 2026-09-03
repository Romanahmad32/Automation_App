import 'package:automation_app/features/word_automation/presentation/utils/betrag_eingabe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Leseregel für getippte Beträge — eine Stelle, an der vier Felder hängen:
/// der Betrag je Schadensposition, der Gebührensatz und die beiden
/// RVG-Korrekturfelder.
///
/// Der Fehler, den sie abstellt, hatte keine sichtbare Spur: `1.5` wurde zu
/// 15,00 €, weil jeder Punkt gestrichen wurde. Keine Meldung, kein negativer
/// Betrag, die Vorschau zeigte `15,00` — und im Anspruchsschreiben stand der
/// zehnfache Betrag.
///
/// Die Absicht dahinter war richtig: `.` ist im Deutschen das
/// Tausendertrennzeichen, `1.500` muss 1500 ergeben. Falsch war nur, dass die
/// Regel auch dort griff, wo der Punkt nachweislich keines sein kann.
void main() {
  group('der Punkt als Tausendertrennzeichen', () {
    test('genau drei Ziffern dahinter — dann und nur dann', () {
      expect(betragAusEingabe('1.500'), 1500);
      expect(betragAusEingabe('1.234'), 1234);
      expect(betragAusEingabe('10.000'), 10000);
      expect(betragAusEingabe('-1.500'), -1500);
    });

    test('mehrere Gruppen zählen genauso', () {
      expect(betragAusEingabe('1.234.567,89'), 1234567.89);
    });

    /// Der eigentliche Fehler dieses Issues, Zeile für Zeile aus seiner
    /// Tabelle.
    test('sonst ist der Punkt das Dezimaltrennzeichen', () {
      expect(betragAusEingabe('1.5'), 1.5);
      expect(betragAusEingabe('1.50'), 1.5);
      expect(betragAusEingabe('1234.56'), 1234.56);
    });

    /// `0.500` wäre nach der reinen Dreierregel 500 — schriebe aber niemand so.
    /// Wer eine führende Null tippt, meint die Stelle davor als Ganzes.
    test('eine führende Null macht keine Tausendergruppe', () {
      expect(betragAusEingabe('0.500'), 0.5);
    });

    test('ein Komma hat die Dezimalrolle schon vergeben', () {
      expect(betragAusEingabe('2.560,87'), 2560.87);
      expect(betragAusEingabe('1.500,50'), 1500.5);
      expect(betragAusEingabe('0,50'), 0.5);
    });
  });

  group('was nicht eindeutig ist, wird nicht geraten', () {
    /// Beides zugleich behauptet: eine Dreiergruppe und dahinter noch zwei
    /// Ziffern. Hier ist jede Lesart eine Behauptung über die Absicht.
    test('widersprüchliche Gliederung bleibt unlesbar', () {
      expect(betragAusEingabe('1.234.56'), isNull);
      expect(betragAusEingabe('1.2.3'), isNull);
    });

    test('Beiwerk im Feld bleibt unlesbar', () {
      expect(betragAusEingabe('1.234,56 €'), isNull);
      expect(betragAusEingabe('1 500'), isNull);
      expect(betragAusEingabe('abc'), isNull);
    });

    test('leer ist unlesbar und heißt trotzdem etwas anderes', () {
      expect(betragAusEingabe(''), isNull);
      expect(betragAusEingabe('   '), isNull);
    });
  });

  /// Wer beim Tippen nach dem ersten Tastendruck angeblafft wird, lernt die
  /// Markierung zu übersehen. Deshalb steht hier, welche Zwischenstände beim
  /// Tippen entstehen — und dass sie sich alle lesen.
  test('die Zwischenstände beim Tippen sind lesbar', () {
    for (final zwischenstand in ['1', '1,', '1.', '12', '12,', '1.2', '1.23']) {
      expect(betragAusEingabe(zwischenstand), isNotNull, reason: zwischenstand);
    }
  });

  /// `-0,0` ist numerisch null und deshalb kein negativer Betrag. Achtung bei
  /// der Prüfung: `-0.0 == 0` ist in Dart `true` — nur `isNegative` trennt die
  /// beiden.
  test('-0,0 verlässt das Lesen als 0,0', () {
    expect(betragAusEingabe('-0,0')!.isNegative, isFalse);
    expect(betragAusEingabe('-0,00')!.isNegative, isFalse);
  });

  group('der Hinweis nennt, was dasteht', () {
    test('statt nur „ungültig"', () {
      expect(unlesbarerBetragHinweis('1.234,56 €'), contains('1.234,56 €'));
    });

    /// Sonst zieht eine hineinkopierte Zeile die Meldung unter dem Feld
    /// auseinander.
    test('lange Eingaben werden gekürzt', () {
      final hinweis = unlesbarerBetragHinweis('a' * 100);
      expect(hinweis.length, lessThan(50));
      expect(hinweis, contains('…'));
    });
  });

  group('Schreiben', () {
    test('gibt die deutsche Form ohne überflüssige Nullen zurück', () {
      expect(betragAlsEingabe(1500), '1500');
      expect(betragAlsEingabe(2560.87), '2560,87');
      expect(betragAlsEingabe(1.5), '1,5');
    });

    /// Beide Richtungen an einer Stelle heisst auch: Was hier hinausgeht, muss
    /// dort wieder hereinkommen. Sonst verschöbe ein Zurückblättern im Wizard
    /// die Beträge.
    test('was geschrieben wurde, liest sich wieder', () {
      for (final wert in [0.0, 1.5, 250.0, 2560.87, 1234567.89]) {
        expect(betragAusEingabe(betragAlsEingabe(wert)), wert, reason: '$wert');
      }
    });
  });
}
