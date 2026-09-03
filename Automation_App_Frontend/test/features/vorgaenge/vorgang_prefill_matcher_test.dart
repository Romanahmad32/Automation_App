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

/// Felder ohne gesetzte Datenquelle — der Weg bestehender Vorlagen, deren
/// Namen erst zur Laufzeit über `FeldDatenquelleErkennung` aufgelöst werden.
List<FieldData> ungebunden(List<String> labels) => [
  for (final label in labels) feld(label, FeldDatenquelle.keine),
];

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
    versichererTelefon: '0800/248544533',
    versichererFax: '0800-2485329',
    versichererEmail: 'info@huk-coburg.de',
    versicherungsscheinNr: '999/123456-X',
    versicherungsbeginn: '07.10.2015',
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
    String rechtsgebiet = RechtsgebietWert.verkehrsrecht,
    String? kennzeichen,
    String? geschaedigtenKennzeichen,
    String? unfallDatum,
    String? unfallort,
    String? unfalluhrzeit,
    String? polizeiVorgangsnummer,
  }) {
    return Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      // Zerlegt wie nach `Vorgang.ausAnfrage`: Ohne die Bestandteile fiele
      // `zeichen` auf die volle Referenz zurück, und der Unterschied zwischen
      // Zeichen und Referenz — worum es hier geht — wäre nicht prüfbar.
      laufendeNummer: 84,
      jahr: '26',
      abteilung: 'C03',
      angefragtAm: DateTime(2026, 4, 8),
      rechtsgebiet: rechtsgebiet,
      mandantId: mandantId,
      mandantName: mandantName,
      kennzeichen: kennzeichen,
      geschaedigtenKennzeichen: geschaedigtenKennzeichen,
      unfallDatum: unfallDatum,
      unfallort: unfallort,
      unfalluhrzeit: unfalluhrzeit,
      polizeiVorgangsnummer: polizeiVorgangsnummer,
      antwort: mitAntwort,
    );
  }

  test('füllt Mandantenfelder aus dem Registereintrag', () {
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden([
        'Name des Mandanten',
        'Vorname des Mandanten',
        'Nachname des Mandanten',
        'Straße des Mandanten',
        'PLZ Mandant',
        'Ort des Mandanten',
        'E-Mail des Mandanten',
        'Telefon Mandant',
        'Anschrift des Geschädigten',
      ]),
      vorgang(),
      mandant: mandant,
    );

    expect(result['Name des Mandanten'], 'Erika Mustermann');
    expect(result['Vorname des Mandanten'], 'Erika');
    expect(result['Nachname des Mandanten'], 'Mustermann');
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
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden([
        'Gegnerische Versicherung',
        'Versicherungsschein-Nr.',
        'Unfalldatum',
        'Kennzeichen des Unfallgegners',
        'Aktenzeichen',
        'Referenz',
        'Rechtsgebiet',
      ]),
      vorgang(rechtsgebiet: RechtsgebietWert.verkehrsrecht),
      mandant: mandant,
    );

    expect(result['Gegnerische Versicherung'], 'HUK-COBURG');
    expect(result['Versicherungsschein-Nr.'], '999/123456-X');
    expect(result['Unfalldatum'], '09.03.2026');
    expect(result['Kennzeichen des Unfallgegners'], 'GG XY 123');
    // „Aktenzeichen" meint das Zeichen und kommt ohne Kennzeichen in den
    // Brief; das Kennzeichen trägt nur die volle Referenz, und die bekommt,
    // wer sein Feld auch so nennt (§4.2).
    expect(result['Aktenzeichen'], '84/26 C03');
    expect(result['Referenz'], '84/26 C03_GG-XY 123');
    expect(result['Rechtsgebiet'], 'Verkehrsrecht');
  });

  test('füllt Adressteile und Kontaktwege des Versicherers mit Werten', () {
    // Diese Zuordnungen hingen bis zur Zusammenführung am eigenen Test des
    // abgelösten `VorgangsdatenFieldMatcher`. Die Erkennung prüft nur Name →
    // Quelle; dass hinter jeder Quelle auch das richtige Feld der Antwort
    // steht, hängt allein an diesem Test — sonst fiele ein vertauschtes
    // Telefon/Fax niemandem auf.
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden([
        'Straße der Versicherung',
        'PLZ Versicherer',
        'Ort der Versicherung',
        'Anschrift der Versicherung',
        'E-Mail der Versicherung',
        'Telefon der Versicherung',
        'Fax der Versicherung',
        'Versicherungsbeginn',
      ]),
      vorgang(),
      mandant: mandant,
    );

    expect(result['Straße der Versicherung'], 'Lyoner Str. 10');
    expect(result['PLZ Versicherer'], '60524');
    expect(result['Ort der Versicherung'], 'Frankfurt');
    expect(
      result['Anschrift der Versicherung'],
      'HUK-COBURG, Lyoner Str. 10, 60524 Frankfurt',
    );
    expect(result['E-Mail der Versicherung'], 'info@huk-coburg.de');
    expect(result['Telefon der Versicherung'], '0800/248544533');
    expect(result['Fax der Versicherung'], '0800-2485329');
    expect(result['Versicherungsbeginn'], '07.10.2015');
  });

  test('lässt Felder leer, deren Wert in der Antwort fehlt', () {
    // Nicht dasselbe wie „gar keine Antwort": Die Antwort ist übernommen, nur
    // dieses eine Feld war in der Zentralruf-Mail nicht besetzt.
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden(['Versicherungsschein-Nr.', 'Gegnerische Versicherung']),
      vorgang(mitAntwort: const ZentralrufReplyData(kennzeichen: 'GG XY 123')),
      mandant: mandant,
    );

    expect(result.containsKey('Versicherungsschein-Nr.'), isFalse);
    expect(result.containsKey('Gegnerische Versicherung'), isFalse);
  });

  test('füllt Unfallort, -uhrzeit und Polizei-Vorgangsnummer', () {
    // Diese drei hatten in der abgelösten Heuristik gar keine Entsprechung:
    // Ohne Dropdown blieben sie immer leer, obwohl der Vorgang sie kannte.
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden(['Unfallort', 'Unfalluhrzeit', 'Polizei-Vorgangsnummer']),
      vorgang(
        unfallort: 'Bad Homburg, Louisenstr.',
        unfalluhrzeit: '14:35',
        polizeiVorgangsnummer: 'ST/1234567/2026',
      ),
      mandant: mandant,
    );

    expect(result['Unfallort'], 'Bad Homburg, Louisenstr.');
    expect(result['Unfalluhrzeit'], '14:35');
    expect(result['Polizei-Vorgangsnummer'], 'ST/1234567/2026');
  });

  test('füllt Vorgangsangaben auch ohne übernommene Antwort', () {
    // Die alte Heuristik schöpfte für diese Felder ausschließlich aus der
    // Zentralruf-Antwort — ohne sie blieben sie leer, obwohl der Vorgang die
    // Angabe längst kannte.
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden(['Unfalldatum', 'Kennzeichen', 'Referenz']),
      vorgang(
        mitAntwort: null,
        kennzeichen: 'GG-XY 123',
        unfallDatum: '09.03.2026',
      ),
      mandant: mandant,
    );

    expect(result['Unfalldatum'], '09.03.2026');
    expect(result['Kennzeichen'], 'GG-XY 123');
    expect(result['Referenz'], '84/26 C03_GG-XY 123');
  });

  group('Kennzeichen des Mandanten/Geschädigten', () {
    test('kommt aus dem Vorgang, statt leer zu bleiben', () {
      // Bewusste Verhaltensänderung: Früher lieferte dieses Feld nichts, weil
      // es sonst an den Gegner-Matcher durchgefallen wäre.
      final result = VorgangPrefillMatcher.matchTemplateFields(
        ungebunden(['Kennzeichen des Geschädigten', 'Kennzeichen Mandant']),
        vorgang(geschaedigtenKennzeichen: 'HG-E 1427'),
        mandant: mandant,
      );

      expect(result['Kennzeichen des Geschädigten'], 'HG-E 1427');
      expect(result['Kennzeichen Mandant'], 'HG-E 1427');
    });

    test('bleibt leer — nie das Kennzeichen des Gegners', () {
      // Die Regression, für die es die alte Notbremse gab: Kennt der Vorgang
      // das eigene Fahrzeug nicht, darf keinesfalls das gegnerische einrücken.
      final result = VorgangPrefillMatcher.matchTemplateFields(
        ungebunden(['Kennzeichen des Geschädigten']),
        vorgang(),
        mandant: mandant,
      );

      expect(result.containsKey('Kennzeichen des Geschädigten'), isFalse);
    });
  });

  test('bindet mehrdeutige Platzhalter nicht', () {
    // „VersicherungPlzOrt" lieferte still nur die PLZ. Jetzt liefert er nichts
    // — und der Vorlageneditor sagt warum (FeldNameHinweis).
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden(['VersicherungPlzOrt']),
      vorgang(),
      mandant: mandant,
    );

    expect(result.containsKey('VersicherungPlzOrt'), isFalse);
  });

  test('nutzt den Namens-Schnappschuss, wenn kein Mandant aufgelöst ist', () {
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden(['Name des Mandanten', 'Straße des Mandanten']),
      vorgang(),
    );

    expect(result['Name des Mandanten'], 'Erika Mustermann');
    // Ohne Registereintrag bleibt die Anschrift leer statt geraten.
    expect(result.containsKey('Straße des Mandanten'), isFalse);
  });

  test('ohne Antwort bleiben Versichererfelder leer', () {
    final result = VorgangPrefillMatcher.matchTemplateFields(
      ungebunden(['Gegnerische Versicherung', 'Name des Mandanten']),
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

    test('explizite Quelle gewinnt gegen die Erkennung über den Namen', () {
      // Label klingt nach Mandant, ist aber bewusst auf den Versicherernamen
      // gebunden — die explizite Wahl muss greifen.
      final result = VorgangPrefillMatcher.matchTemplateFields(
        [feld('Name des Mandanten', FeldDatenquelle.versichererName)],
        vorgang(),
        mandant: mandant,
      );

      expect(result['Name des Mandanten'], 'HUK-COBURG');
    });

    test('eine gesetzte Quelle bindet auch mehrdeutige Namen', () {
      // Bestehende Vorlagen laufen unverändert weiter: Wer die Quelle einmal
      // gewählt hat, bekommt sie — der Mehrdeutigkeitshinweis gilt nur für
      // Felder, die noch niemand gebunden hat.
      final result = VorgangPrefillMatcher.matchTemplateFields(
        [feld('VersicherungPlzOrt', FeldDatenquelle.versichererPlz)],
        vorgang(),
        mandant: mandant,
      );

      expect(result['VersicherungPlzOrt'], '60524');
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

      final felder = [
        feld('Unfalldatum', FeldDatenquelle.unfalldatum),
        feld('Versicherer', FeldDatenquelle.keine),
        feld('Ort des Mandanten', FeldDatenquelle.mandantOrt),
      ];

      final result = VorgangPrefillMatcher.matchTemplateFields(
        felder,
        mitWerten,
        mandant: mandant,
      );

      // Gespeichert schlägt Datenquelle und Erkennung …
      expect(result['Unfalldatum'], '10.03.2026');
      expect(result['Versicherer'], 'HUK-COBURG Allgemeine');
      // … Felder ohne gespeicherten Wert kommen weiter aus den Quellen, und
      // Werte fremder Vorlagen tauchen nicht auf.
      expect(result['Ort des Mandanten'], 'Bad Homburg');
      expect(result.containsKey('Fremdes Feld'), isFalse);

      // Die Herkunft weist genau die zwei gespeicherten Werte aus.
      final herkunft = VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
        felder,
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
