import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalisiert Schreibvarianten in die Domänen-Konvention', () {
    expect(normalizeKennzeichen('gg-xy123'), 'GG-XY 123');
    expect(normalizeKennzeichen('GG XY 123'), 'GG-XY 123');
    expect(normalizeKennzeichen('  HG-E 1427 '), 'HG-E 1427');
    expect(normalizeKennzeichen('HG-E1427H'), 'HG-E 1427H');
  });

  test('lässt nicht erkennbare Schreibweisen (bereinigt) unverändert', () {
    expect(normalizeKennzeichen('kein kennzeichen'), 'kein kennzeichen');
    expect(normalizeKennzeichen(null), isNull);
    expect(normalizeKennzeichen('   '), '   ');
  });

  test('gleichesKennzeichen vergleicht tolerant, aber nie leer gegen leer', () {
    expect(gleichesKennzeichen('gg-xy123', 'GG XY 123'), isTrue);
    expect(gleichesKennzeichen('GG-XY 123', 'GG-XY 322'), isFalse);
    expect(gleichesKennzeichen(null, 'GG-XY 123'), isFalse);
    expect(gleichesKennzeichen(null, null), isFalse);
  });

  group('istKennzeichen', () {
    /// Dieselbe Toleranz wie [normalizeKennzeichen]: Was sich in die
    /// Konvention überführen lässt, ist ein Kennzeichen. Liefen die beiden
    /// auseinander, beanstandete das Formular einen Wert, den die App selbst
    /// aus dem Register angeboten hat.
    test('erkennt jede Schreibweise, die normalisiert werden kann', () {
      for (final wert in [
        'HG-E 1427',
        'hg-e 1427',
        'HE1427',
        'GG XY 123',
        '  HG-E 1427 ',
        'HG-E1427H',
        'B-A 1',
      ]) {
        expect(istKennzeichen(wert), isTrue, reason: wert);
      }
    });

    test('leer und null sind kein Kennzeichen', () {
      expect(istKennzeichen(null), isFalse);
      expect(istKennzeichen(''), isFalse);
      expect(istKennzeichen('   '), isFalse);
    });

    test('was kein Kennzeichen ist, wird nicht dazu erklärt', () {
      for (final wert in [
        'kein kennzeichen',
        'HG-E',
        '1427',
        'HGEF-XY 1427',
        'HG-E 12345',
        'HG-E 1427X',
      ]) {
        expect(istKennzeichen(wert), isFalse, reason: wert);
      }
    });

    /// Mehrdeutig heisst „noch nicht entschieden", nicht „gültig": Ein geratenes
    /// Kennzeichen benennt ein anderes Fahrzeug.
    test('ein mehrdeutiger Wert gilt (noch) nicht als Kennzeichen', () {
      expect(istKennzeichen('HGE1427'), isFalse);
      expect(istKennzeichen('FABC12'), isFalse);
    });
  });

  /// #17/#18: Ohne Trennzeichen zwischen Unterscheidungszeichen und
  /// Erkennungsbuchstaben ist die Aufteilung bei 3 und 4 Buchstaben offen —
  /// beide Gruppen sind variabel lang. Genau das steht hier fest, denn daran
  /// hängt, was die App normalisiert und was sie zurückfragt.
  group('kennzeichenLesarten', () {
    test('mit Trennzeichen gibt es genau eine Lesart', () {
      expect(kennzeichenLesarten('HG-E 1427'), ['HG-E 1427']);
      expect(kennzeichenLesarten('hg e 1427'), ['HG-E 1427']);
      expect(kennzeichenLesarten('HG-E1427H'), ['HG-E 1427H']);
    });

    test('ohne Trennzeichen sind 3 und 4 Buchstaben mehrdeutig', () {
      expect(kennzeichenLesarten('HGE1427'), ['HG-E 1427', 'H-GE 1427']);
      expect(kennzeichenLesarten('FABC12'), ['FAB-C 12', 'FA-BC 12']);
    });

    /// Bei 2 Buchstaben bleibt nur 1+1, bei 5 nur 3+2 — die Grenzen der beiden
    /// Gruppen (1–3 und 1–2) lassen dort nichts anderes zu.
    test('1–2 und 5 Buchstaben bleiben eindeutig', () {
      expect(kennzeichenLesarten('HE1427'), ['H-E 1427']);
      expect(kennzeichenLesarten('ABCDE123'), ['ABC-DE 123']);
    });

    test('was kein Kennzeichen ist, hat keine Lesart', () {
      expect(kennzeichenLesarten('kein kennzeichen'), isEmpty);
      expect(kennzeichenLesarten('HG-E 12345'), isEmpty);
      expect(kennzeichenLesarten(null), isEmpty);
      expect(kennzeichenLesarten('   '), isEmpty);
    });
  });

  group('istMehrdeutigesKennzeichen', () {
    test('trennt „mehrdeutig" von „eindeutig" und „unlesbar"', () {
      expect(istMehrdeutigesKennzeichen('HGE1427'), isTrue);
      expect(istMehrdeutigesKennzeichen('FABC12'), isTrue);
      expect(istMehrdeutigesKennzeichen('HG-E 1427'), isFalse);
      expect(istMehrdeutigesKennzeichen('HE1427'), isFalse);
      expect(istMehrdeutigesKennzeichen('kein kennzeichen'), isFalse);
      expect(istMehrdeutigesKennzeichen(null), isFalse);
    });
  });

  /// Der Kern der Regel: Ein mehrdeutiger Wert wird **nicht** aufgeteilt.
  /// Falsch aufgeteilt benennt er ein anderes Fahrzeug, und das stünde danach
  /// unbemerkt in Referenz, Registereintrag und Anspruchsschreiben.
  test('mehrdeutige Werte bleiben stehen, statt geraten zu werden', () {
    expect(normalizeKennzeichen('HGE1427'), 'HGE1427');
    expect(normalizeKennzeichen('FABC12'), 'FABC12');
    expect(normalizeKennzeichen(' HGE  1427 '), 'HGE 1427');
  });

  /// Wiedererkennen darf großzügiger sein als Erfassen: Sagt **eine** Seite die
  /// Aufteilung, ist der Wagen derselbe. Sonst böte die Auswahlhilfe ihn
  /// zweimal an, und eine Zentralruf-Antwort fände ihren Vorgang nicht.
  test('gleichesKennzeichen erkennt einen mehrdeutigen Wert wieder', () {
    expect(gleichesKennzeichen('HGE1427', 'HG-E 1427'), isTrue);
    expect(gleichesKennzeichen('hg-e 1427', 'HGE1427'), isTrue);
    expect(gleichesKennzeichen('HGE1427', 'H-GE 1427'), isTrue);
    expect(gleichesKennzeichen('HGE1427', 'HG-E 1428'), isFalse);
    expect(gleichesKennzeichen('HGE1427', 'FABC12'), isFalse);
  });
}
