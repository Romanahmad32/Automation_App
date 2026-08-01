import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
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
  const antwort = ZentralrufReplyData(
    referenz: '84/26 C03_GG-XY 123',
    kennzeichen: 'GG-XY 123',
    unfallDatum: '09.03.2026',
    versichererName: 'HUK-COBURG',
  );

  final mandant = Mandant(
    id: 7,
    vorname: 'Erika',
    nachname: 'Mustermann',
    strasseHausnummer: 'Hauptstr. 1',
    erstelltAm: DateTime(2026, 1, 1),
  );

  final vorgang = Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 4, 8),
    mandantId: 7,
    mandantName: 'Erika Mustermann',
    unfallort: 'Bad Homburg',
    antwort: antwort,
    feldWerte: const {'Schadenshöhe': '2.500,00 €'},
  );

  test('kennzeichnet die Herkunft je expliziter Datenquelle', () {
    final result = VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
      [
        feld('Name', FeldDatenquelle.mandantName),
        feld('Versicherung', FeldDatenquelle.versichererName),
        feld('Ort des Unfalls', FeldDatenquelle.unfallort),
        feld('Unfalltag', FeldDatenquelle.unfalldatum),
      ],
      vorgang,
      mandant: mandant,
    );

    expect(result['Name'], const PrefillWert('Erika Mustermann', PrefillQuelle.mandant));
    expect(
      result['Versicherung'],
      const PrefillWert('HUK-COBURG', PrefillQuelle.antwort),
    );
    expect(
      result['Ort des Unfalls'],
      const PrefillWert('Bad Homburg', PrefillQuelle.vorgang),
    );
    // Unfalldatum ist am Vorgang leer → tatsächlich aus der Antwort.
    expect(
      result['Unfalltag'],
      const PrefillWert('09.03.2026', PrefillQuelle.antwort),
    );
  });

  test('Namens-Schnappschuss ohne Registereintrag zählt als Vorgangsdatum', () {
    final result = VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
      [feld('Name', FeldDatenquelle.mandantName)],
      vorgang,
    );

    expect(
      result['Name'],
      const PrefillWert('Erika Mustermann', PrefillQuelle.vorgang),
    );
  });

  test('heuristische Felder tragen die Herkunft ihres Datenbestands', () {
    final result = VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
      [
        feld('Straße des Mandanten', FeldDatenquelle.keine),
        feld('Gegnerische Versicherung', FeldDatenquelle.keine),
        feld('Rechtsgebiet', FeldDatenquelle.keine),
      ],
      vorgang,
      mandant: mandant,
    );

    expect(result['Straße des Mandanten']?.quelle, PrefillQuelle.mandant);
    expect(result['Gegnerische Versicherung']?.quelle, PrefillQuelle.antwort);
    expect(result['Rechtsgebiet']?.quelle, PrefillQuelle.vorgang);
  });

  test('gespeicherte Feldwerte gewinnen und heißen „gespeichert"', () {
    final result = VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
      [feld('Schadenshöhe', FeldDatenquelle.keine)],
      vorgang,
      mandant: mandant,
    );

    expect(
      result['Schadenshöhe'],
      const PrefillWert('2.500,00 €', PrefillQuelle.gespeichert),
    );
  });
}
