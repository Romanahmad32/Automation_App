import 'package:automation_app/features/form_template_setup/domain/services/vorlagenname_vorschlag.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Namensvorschlag aus dem Dateinamen (#104, Stufe 3b) — der Anfang des
/// Ablaufs „Datei zuerst".
///
/// Der wichtigste Fall steht in der Mitte: **Beide Word-Dateien derselben
/// Vorlage müssen denselben Vorschlag ergeben.** Sonst hinge der Name daran,
/// welche der beiden gleichwertigen Dateien der Anwalt zuerst wählt.
void main() {
  group('Dateiname', () {
    test('kommt aus dem Pfad, mit beiden Trennern und mit Endung', () {
      expect(
        VorlagennameVorschlag.dateiname(r'C:\Vorlagen\HGN.docx'),
        'HGN.docx',
      );
      expect(
        VorlagennameVorschlag.dateiname('/home/kanzlei/HGN.docx'),
        'HGN.docx',
      );
      expect(VorlagennameVorschlag.dateiname('HGN.docx'), 'HGN.docx');
    });
  });

  group('Vorschlag', () {
    test('Endung weg, Trennzeichen zu Leerzeichen, Mehrfache zusammen', () {
      expect(
        VorlagennameVorschlag.ausPfad(r'C:\Vorlagen\Anspruch_an__Gegner.docx'),
        'Anspruch an Gegner',
      );
      expect(
        VorlagennameVorschlag.ausPfad('Erste-Anfrage.docx'),
        'Erste Anfrage',
      );
      expect(VorlagennameVorschlag.ausPfad('  Kurz  .docx'), 'Kurz');
    });

    test('das Präfix der Kanzleiablage fällt weg — ohne Rücksicht auf '
        'Groß-/Kleinschreibung', () {
      expect(
        VorlagennameVorschlag.ausPfad(r'C:\V\VORLAGE Anspruchsschreiben.docx'),
        'Anspruchsschreiben',
      );
      expect(VorlagennameVorschlag.ausPfad('vorlage Mahnung.docx'), 'Mahnung');
    });

    test('„Vorlage" nur als ganzes Wort — sonst verlöre „Vorlagenwechsel" '
        'seinen Anfang', () {
      expect(
        VorlagennameVorschlag.ausPfad('Vorlagenwechsel.docx'),
        'Vorlagenwechsel',
      );
    });

    test('beide Dateien derselben Vorlage ergeben denselben Vorschlag', () {
      // Der Grund für die Suffixliste: Die beiden Word-Dateien sind
      // gleichwertig, und welche zuerst gewählt wird, ist Zufall der Ablage.
      const erwartet = 'Anspruchsschreiben';
      expect(
        VorlagennameVorschlag.ausPfad(
          r'C:\V\VORLAGE Anspruchsschreiben ohne Auflistung.docx',
        ),
        erwartet,
      );
      expect(
        VorlagennameVorschlag.ausPfad(
          r'C:\V\VORLAGE Anspruchsschreiben mit Auflistung.docx',
        ),
        erwartet,
      );
      expect(
        VorlagennameVorschlag.ausPfad(
          r'C:\V\VORLAGE Anspruchsschreiben-SA.docx',
        ),
        erwartet,
      );
      expect(
        VorlagennameVorschlag.ausPfad(
          r'C:\V\VORLAGE Anspruchsschreiben mit Schadensaufstellung.docx',
        ),
        erwartet,
      );
    });

    test('mehrere Suffixe hintereinander fallen alle weg', () {
      expect(
        VorlagennameVorschlag.ausPfad('Anspruch_SA ohne Auflistung.docx'),
        'Anspruch',
      );
    });

    test('bleibt nichts übrig, gibt es keinen Vorschlag', () {
      // Lieber gar keiner als einer, den der Anwalt erst wieder wegräumt.
      expect(VorlagennameVorschlag.ausPfad(r'C:\V\VORLAGE.docx'), '');
      expect(VorlagennameVorschlag.ausPfad('_.docx'), '');
      expect(VorlagennameVorschlag.ausPfad('   .docx'), '');
    });
  });
}
