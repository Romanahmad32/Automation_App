import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

FieldData feld(String label, FeldDatenquelle quelle) => FieldData(
  order: 0,
  label: label,
  required: false,
  inputType: InputType.text,
  datenquelle: quelle,
);

void main() {
  // Antwortdaten aus "Beispiele/Anwortemail von Zentralruf.txt".
  const antwort = ZentralrufReplyData(
    referenz: '84/26 C03_GG-XY 123',
    kennzeichen: 'GG XY 123',
    unfallDatum: '09.03.2026',
    versichererName: 'HUK-COBURG',
    versichererStrasse: 'Lyoner Str. 10',
    versichererPlz: '60524',
    versichererOrt: 'Frankfurt',
    versicherungsscheinNr: '999/123456-X',
  );

  final mandant = Mandant(
    id: 7,
    vorname: 'Erika',
    nachname: 'Mustermann',
    strasseHausnummer: 'Hauptstr. 1',
    postleitzahl: '61348',
    ort: 'Bad Homburg',
    emailAdresse: 'erika@example.de',
    telefonnummer: '06172/123456',
    erstelltAm: DateTime(2026, 1, 1),
  );

  Vorgang vorgang({
    ZentralrufReplyData? mitAntwort = antwort,
    int? mandantId = 7,
    String? mandantName = 'Erika Mustermann',
    Rechtsgebiet rechtsgebiet = Rechtsgebiet.verkehrsrecht,
  }) {
    return Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 4, 8),
      rechtsgebiet: rechtsgebiet,
      mandantId: mandantId,
      mandantName: mandantName,
      antwort: mitAntwort,
    );
  }

  test('füllt Mandantenfelder aus dem Registereintrag', () {
    final result = VorgangPrefillMatcher.matchFields(
      [
        'Name des Mandanten',
        'Straße des Mandanten',
        'PLZ Mandant',
        'Ort des Mandanten',
        'E-Mail des Mandanten',
        'Telefon Mandant',
        'Anschrift des Geschädigten',
      ],
      vorgang(),
      mandant: mandant,
    );

    expect(result['Name des Mandanten'], 'Erika Mustermann');
    expect(result['Straße des Mandanten'], 'Hauptstr. 1');
    expect(result['PLZ Mandant'], '61348');
    expect(result['Ort des Mandanten'], 'Bad Homburg');
    expect(result['E-Mail des Mandanten'], 'erika@example.de');
    expect(result['Telefon Mandant'], '06172/123456');
    expect(
      result['Anschrift des Geschädigten'],
      'Erika Mustermann, Hauptstr. 1, 61348 Bad Homburg',
    );
  });

  test('füllt Antwort- und Rechtsgebietsfelder aus dem Vorgang', () {
    final result = VorgangPrefillMatcher.matchFields(
      [
        'Gegnerische Versicherung',
        'Versicherungsschein-Nr.',
        'Unfalldatum',
        'Kennzeichen des Unfallgegners',
        'Aktenzeichen',
        'Rechtsgebiet',
      ],
      vorgang(rechtsgebiet: Rechtsgebiet.verkehrsrecht),
      mandant: mandant,
    );

    expect(result['Gegnerische Versicherung'], 'HUK-COBURG');
    expect(result['Versicherungsschein-Nr.'], '999/123456-X');
    expect(result['Unfalldatum'], '09.03.2026');
    expect(result['Kennzeichen des Unfallgegners'], 'GG XY 123');
    expect(result['Aktenzeichen'], '84/26 C03_GG-XY 123');
    expect(result['Rechtsgebiet'], 'Verkehrsrecht');
  });

  test('rät kein Kennzeichen des Mandanten/Geschädigten', () {
    final result = VorgangPrefillMatcher.matchFields(
      ['Kennzeichen des Geschädigten', 'Kennzeichen Mandant'],
      vorgang(),
      mandant: mandant,
    );

    expect(result.containsKey('Kennzeichen des Geschädigten'), isFalse);
    expect(result.containsKey('Kennzeichen Mandant'), isFalse);
  });

  test('nutzt den Namens-Schnappschuss, wenn kein Mandant aufgelöst ist', () {
    final result = VorgangPrefillMatcher.matchFields([
      'Name des Mandanten',
      'Straße des Mandanten',
    ], vorgang());

    expect(result['Name des Mandanten'], 'Erika Mustermann');
    // Ohne Registereintrag bleibt die Anschrift leer statt geraten.
    expect(result.containsKey('Straße des Mandanten'), isFalse);
  });

  test('ohne Antwort bleiben Versichererfelder leer', () {
    final result = VorgangPrefillMatcher.matchFields(
      ['Gegnerische Versicherung', 'Name des Mandanten'],
      vorgang(mitAntwort: null),
      mandant: mandant,
    );

    expect(result.containsKey('Gegnerische Versicherung'), isFalse);
    expect(result['Name des Mandanten'], 'Erika Mustermann');
  });

  group('matchTemplateFields (explizite Datenquelle)', () {
    test('füllt frei benannte Felder über die gewählte Quelle', () {
      final result = VorgangPrefillMatcher.matchTemplateFields(
        [
          // Genau das gemeldete Szenario: ein „Adresse"-Feld soll die Anschrift
          // OHNE Name liefern, „Versicherungsschein" die Nummer (nicht den Namen).
          feld('Versicherer Adresse', FeldDatenquelle.versichererAdresse),
          feld('Versicherungsschein', FeldDatenquelle.versicherungsscheinNr),
          feld('Versicherer', FeldDatenquelle.versichererName),
        ],
        vorgang(),
        mandant: mandant,
      );

      expect(result['Versicherer Adresse'], 'Lyoner Str. 10, 60524 Frankfurt');
      expect(result['Versicherungsschein'], '999/123456-X');
      expect(result['Versicherer'], 'HUK-COBURG');
    });

    test('explizite Quelle gewinnt gegen die Namens-Heuristik', () {
      // Label klingt nach Mandant, ist aber bewusst auf den Versicherernamen
      // gebunden — die explizite Wahl muss greifen.
      final result = VorgangPrefillMatcher.matchTemplateFields(
        [feld('Name des Mandanten', FeldDatenquelle.versichererName)],
        vorgang(),
        mandant: mandant,
      );

      expect(result['Name des Mandanten'], 'HUK-COBURG');
    });

    test('ungebundene Felder nutzen weiterhin die Heuristik', () {
      final result = VorgangPrefillMatcher.matchTemplateFields(
        [feld('Unfalldatum', FeldDatenquelle.keine)],
        vorgang(),
        mandant: mandant,
      );

      expect(result['Unfalldatum'], '09.03.2026');
    });
  });

  group('gespeicherte Feldwerte (Rückfluss)', () {
    test('beim letzten Schreiben bestätigte Werte gewinnen über alles', () {
      final mitWerten = vorgang().copyWith(
        feldWerte: const {
          'Unfalldatum': '10.03.2026',
          'Versicherer': 'HUK-COBURG Allgemeine',
          'Fremdes Feld': 'gehört zu anderer Vorlage',
        },
      );

      final result = VorgangPrefillMatcher.matchTemplateFields(
        [
          feld('Unfalldatum', FeldDatenquelle.unfalldatum),
          feld('Versicherer', FeldDatenquelle.keine),
          feld('Ort des Mandanten', FeldDatenquelle.mandantOrt),
        ],
        mitWerten,
        mandant: mandant,
      );

      // Gespeichert schlägt Datenquelle und Heuristik …
      expect(result['Unfalldatum'], '10.03.2026');
      expect(result['Versicherer'], 'HUK-COBURG Allgemeine');
      // … Felder ohne gespeicherten Wert kommen weiter aus den Quellen, und
      // Werte fremder Vorlagen tauchen nicht auf.
      expect(result['Ort des Mandanten'], 'Bad Homburg');
      expect(result.containsKey('Fremdes Feld'), isFalse);

      // Die Herkunft weist genau die zwei gespeicherten Werte aus.
      final herkunft = VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
        [
          feld('Unfalldatum', FeldDatenquelle.unfalldatum),
          feld('Versicherer', FeldDatenquelle.keine),
          feld('Ort des Mandanten', FeldDatenquelle.mandantOrt),
        ],
        mitWerten,
        mandant: mandant,
      );
      expect(
        herkunft.values
            .where((wert) => wert.quelle == PrefillQuelle.gespeichert)
            .length,
        2,
      );
    });

    test('leere gespeicherte Werte überschreiben nichts', () {
      final mitWerten = vorgang().copyWith(
        feldWerte: const {'Unfalldatum': '  '},
      );

      final result = VorgangPrefillMatcher.matchTemplateFields(
        [feld('Unfalldatum', FeldDatenquelle.unfalldatum)],
        mitWerten,
        mandant: mandant,
      );

      expect(result['Unfalldatum'], '09.03.2026');
    });
  });
}
