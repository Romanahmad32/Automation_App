import 'dart:convert';
import 'dart:io';

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

  /// Die Frage, die den Hinweis unter dem Feld still hält, solange noch
  /// getippt wird (#130). Sie hat nur einen Auftrag: **kein Fehlalarm auf dem
  /// Weg zu einem gewöhnlichen Kennzeichen** — und trotzdem sofort etwas
  /// sagen, wo nie eines entstehen kann.
  group('beginntWieKennzeichen', () {
    /// Zeichen für Zeichen `HG-E 1427`: Auf diesem ganzen Weg darf nichts
    /// beanstandet werden. Genau das tat die erste Fassung — sie meldete bei
    /// acht von neun Zeichen „nicht erkannt".
    test('jede Vorsilbe eines Kennzeichens ist ein Anfang', () {
      const ziel = 'HG-E 1427';
      for (var laenge = 1; laenge <= ziel.length; laenge++) {
        final vorsilbe = ziel.substring(0, laenge);
        expect(beginntWieKennzeichen(vorsilbe), isTrue, reason: vorsilbe);
      }
    });

    test('auch klein getippt und ohne Trennzeichen', () {
      for (final wert in ['h', 'hg', 'hg-', 'hg-e', 'hge', 'hge14', 'abcde']) {
        expect(beginntWieKennzeichen(wert), isTrue, reason: wert);
      }
    });

    /// Der Gegenbeweis, und der Grund, das am Muster zu entscheiden statt am
    /// „ist noch kurz": Hinter der Nummer lässt sich keine Buchstabengruppe
    /// mehr nachschieben. Ein NATO-Kennzeichen bekommt seinen Hinweis deshalb
    /// sofort und nicht erst beim Verlassen des Felds.
    test('was nie ein Kennzeichen wird, ist kein Anfang', () {
      for (final wert in [
        'X-1234', // NATO: nur eine Buchstabengruppe, Nummer schon da
        'Y-123456',
        'THW-12345',
        '123 ABC', // Versicherungskennzeichen
        '0 12-345',
        'HG-E 12345',
        'HGEF-XY 1427',
        'mein Auto',
        'der blaue Kombi',
        '',
        '   ',
      ]) {
        expect(beginntWieKennzeichen(wert), isFalse, reason: wert);
      }
      expect(beginntWieKennzeichen(null), isFalse);
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

  /// Der Kern der Regel: Ein mehrdeutiger Wert wird **nicht** aufgeteilt.
  /// Falsch aufgeteilt benennt er ein anderes Fahrzeug, und das stünde danach
  /// unbemerkt in Referenz, Registereintrag und Anspruchsschreiben.
  test('mehrdeutige Werte bleiben stehen, statt geraten zu werden', () {
    expect(normalizeKennzeichen('HGE1427'), 'HGE1427');
    expect(normalizeKennzeichen('FABC12'), 'FABC12');
    expect(normalizeKennzeichen(' HGE  1427 '), 'HGE 1427');
  });

  /// Wiedererkennen darf großzügiger sein als Anmerken: Sagt **eine** Seite die
  /// Aufteilung, ist der Wagen derselbe. Sonst böte die Auswahlhilfe ihn
  /// zweimal an, und eine Zentralruf-Antwort fände ihren Vorgang nicht.
  test('gleichesKennzeichen erkennt einen mehrdeutigen Wert wieder', () {
    expect(gleichesKennzeichen('HGE1427', 'HG-E 1427'), isTrue);
    expect(gleichesKennzeichen('hg-e 1427', 'HGE1427'), isTrue);
    expect(gleichesKennzeichen('HGE1427', 'H-GE 1427'), isTrue);
    expect(gleichesKennzeichen('HGE1427', 'HG-E 1428'), isFalse);
    expect(gleichesKennzeichen('HGE1427', 'FABC12'), isFalse);
  });

  /// Dieselbe Tabelle liest das Backend (`KennzeichenVergleichTests`). Beide
  /// Seiten ordnen Zentralruf-Antworten Vorgängen zu und rechneten bis #144
  /// verschieden — ein neuer Fall gehört deshalb in die Tabelle, nicht hierher.
  group('gemeinsame Falltabelle docs/kennzeichen_faelle.json', () {
    final faelle =
        jsonDecode(File('../docs/kennzeichen_faelle.json').readAsStringSync())
            as Map<String, dynamic>;
    List<Map<String, dynamic>> abschnitt(String name) =>
        (faelle[name] as List<dynamic>).cast<Map<String, dynamic>>();

    test('Lesarten wie im Backend', () {
      for (final fall in abschnitt('lesarten')) {
        final eingabe = fall['eingabe'] as String?;
        final erwartet = (fall['lesarten'] as List<dynamic>).cast<String>();
        expect(
          kennzeichenLesarten(eingabe),
          erwartet,
          reason: 'Eingabe: $eingabe',
        );
      }
    });

    test('Vergleich wie im Backend, in beiden Richtungen', () {
      for (final fall in abschnitt('vergleiche')) {
        final a = fall['a'] as String?;
        final b = fall['b'] as String?;
        final gleich = fall['gleich'] as bool;
        expect(gleichesKennzeichen(a, b), gleich, reason: '"$a" gegen "$b"');
        expect(gleichesKennzeichen(b, a), gleich, reason: '"$b" gegen "$a"');
      }
    });
  });
}
