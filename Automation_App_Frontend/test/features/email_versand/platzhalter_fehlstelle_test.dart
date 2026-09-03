import 'package:automation_app/features/email_versand/domain/services/platzhalter_fehlstelle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Warum ein Platzhalter leer geblieben ist (§4.7).
///
/// Der Fall, der diese Datei trägt: Ein Tippfehler im Platzhalternamen war
/// vorher von einer wirklich fehlenden Angabe nicht zu unterscheiden. Beide
/// ergaben „bleibt leer — die Zeile entfällt", und die eine Aufgabe ist
/// „Schreibweise berichtigen", die andere „Daten nachpflegen".
void main() {
  group('was beim Verfassen entsteht', () {
    test('Anrede und Zusatzgruß verweisen nach oben in den Dialog', () {
      expect(
        PlatzhalterFehlstelle.fuer('Anrede', mitVorgang: true),
        'wird oben im Dialog gewählt',
      );
      expect(
        PlatzhalterFehlstelle.fuer('Zusatzgruß', mitVorgang: false),
        'wird oben im Dialog gewählt',
        reason: 'auch ohne Vorgang — der Gruss haengt nicht an ihm',
      );
    });

    test('sie tragen keine Bezeichnung, ihr Name sagt es selbst', () {
      expect(PlatzhalterFehlstelle.bezeichnungFuer('Anrede'), isEmpty);
      expect(PlatzhalterFehlstelle.bezeichnungFuer('Zusatzgruß'), isEmpty);
    });
  });

  group('ein Name, den es nicht gibt', () {
    test('wird als Schreibweise gemeldet, nicht als fehlende Angabe', () {
      final satz = PlatzhalterFehlstelle.fuer('Adresse', mitVorgang: true);

      expect(satz, contains('kein Feld dieses Namens'));
      expect(satz, contains('Schreibweise'));
    });

    test('auch ohne Vorgang bleibt die Schreibweise der nähere Grund', () {
      // Sonst hiesse es „kein Vorgang gewaehlt", und der Anwalt waehlte einen
      // — ohne dass sich etwas aendert.
      expect(
        PlatzhalterFehlstelle.fuer('Adresse', mitVorgang: false),
        contains('kein Feld dieses Namens'),
      );
    });
  });

  group('eine Angabe, die fehlt', () {
    test('ohne Vorgang fehlt die Akte, nicht das Feld', () {
      expect(
        PlatzhalterFehlstelle.fuer('PolizeiVorgangsnummer', mitVorgang: false),
        'kein Vorgang gewählt — oben im Dialog wählbar',
      );
    });

    test('Mandantenfelder zeigen ins Register', () {
      expect(
        PlatzhalterFehlstelle.fuer('MandantTelefon', mitVorgang: true),
        'im Mandantenregister nicht erfasst',
      );
    });

    test('Versichererfelder nennen beide Quellen', () {
      expect(
        PlatzhalterFehlstelle.fuer('VersichererFax', mitVorgang: true),
        contains('Zentralruf-Antwort'),
      );
    });

    test('Vorgangsfelder zeigen auf den Vorgang', () {
      expect(
        PlatzhalterFehlstelle.fuer('Unfallort', mitVorgang: true),
        'am Vorgang nicht erfasst',
      );
    });
  });

  group('die Bezeichnung kommt aus dem Katalog', () {
    test('sie nennt die Quelle im Klartext', () {
      expect(
        PlatzhalterFehlstelle.bezeichnungFuer('MandantTelefon'),
        'Mandant · Telefon',
      );
      expect(
        PlatzhalterFehlstelle.bezeichnungFuer('PolizeiVorgangsnummer'),
        'Polizei-Vorgangsnummer',
      );
    });

    test('ein unbekannter Name hat keine', () {
      expect(PlatzhalterFehlstelle.bezeichnungFuer('Adresse'), isEmpty);
    });
  });

  group('eine misslungene Beugung', () {
    test('wird als solche erklärt, nicht als unbekannter Name', () {
      // Der Schrägstrich fällt beim Normalisieren weg — vorher landete
      // `{{Mandant/}}` bei „kein Feld dieses Namens", und das schickt den
      // Anwalt in die falsche Richtung: Der Name ist richtig, die Formen
      // sind es nicht.
      expect(
        PlatzhalterFehlstelle.fuer('Mandant/', mitVorgang: true),
        contains('Beugung unvollständig'),
      );
      expect(
        PlatzhalterFehlstelle.fuer('a/b/c/d', mitVorgang: false),
        contains('zwei oder drei Formen erwartet'),
        reason: 'auch ohne Vorgang — die Formen stehen in der Vorlage',
      );
    });

    test('die Erklärung nennt die gemeinte Schreibweise', () {
      expect(
        PlatzhalterFehlstelle.fuer('Mandant/', mitVorgang: true),
        contains('{{Mandant/Mandantin}}'),
      );
    });

    test('eine Beugung trägt ihre Bezeichnung, kein Katalogname', () {
      expect(
        PlatzhalterFehlstelle.bezeichnungFuer('Geschädigter/Geschädigte'),
        'Beugung nach der Anredeart',
      );
    });
  });
}
