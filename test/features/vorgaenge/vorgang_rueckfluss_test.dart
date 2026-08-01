import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_rueckfluss.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:flutter_test/flutter_test.dart';

FieldData feld(String label, FeldDatenquelle quelle) => FieldData(
  order: 0,
  label: label,
  required: false,
  inputType: InputType.text,
  datenquelle: quelle,
);

void main() {
  final vorgang = Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 4, 8),
    unfallort: 'Frankfurt',
  );

  test('speichert Formularwerte und Schadensaufstellung am Vorgang', () {
    const aufstellung = DamageListing(
      items: [DamageItem(description: 'Reparatur', amount: 1000)],
    );

    final ergebnis = VorgangRueckfluss.uebernehmeWizardErgebnis(
      vorgang,
      fields: [feld('Versicherer', FeldDatenquelle.versichererName)],
      formData: const {'Versicherer': 'HUK-COBURG'},
      schadensaufstellung: aufstellung,
    );

    expect(ergebnis.feldWerte, const {'Versicherer': 'HUK-COBURG'});
    expect(ergebnis.schadensaufstellung, aufstellung);
  });

  test('schreibt explizit zugeordnete Unfalldaten in den Vorgang zurück', () {
    final ergebnis = VorgangRueckfluss.uebernehmeWizardErgebnis(
      vorgang,
      fields: [
        feld('Ort des Unfalls', FeldDatenquelle.unfallort),
        feld('Uhrzeit', FeldDatenquelle.unfalluhrzeit),
        feld('Polizei-Nr.', FeldDatenquelle.polizeiVorgangsnummer),
        feld('Unfalltag', FeldDatenquelle.unfalldatum),
        feld('Eigenes Kennzeichen', FeldDatenquelle.kennzeichenMandant),
      ],
      formData: const {
        'Ort des Unfalls': 'Bad Homburg',
        'Uhrzeit': '14:30',
        'Polizei-Nr.': 'ST/123456/2026',
        'Unfalltag': '09.03.2026',
        'Eigenes Kennzeichen': 'HG-E 1427',
      },
    );

    expect(ergebnis.unfallort, 'Bad Homburg');
    expect(ergebnis.unfalluhrzeit, '14:30');
    expect(ergebnis.polizeiVorgangsnummer, 'ST/123456/2026');
    expect(ergebnis.unfallDatum, '09.03.2026');
    expect(ergebnis.geschaedigtenKennzeichen, 'HG-E 1427');
  });

  test('heuristische und leere Felder ändern die Vorgangsfelder nicht', () {
    final ergebnis = VorgangRueckfluss.uebernehmeWizardErgebnis(
      vorgang,
      fields: [
        // Klingt nach Unfallort, ist aber nicht explizit zugeordnet.
        feld('Unfallort', FeldDatenquelle.keine),
        feld('Uhrzeit', FeldDatenquelle.unfalluhrzeit),
      ],
      formData: const {'Unfallort': 'Kassel', 'Uhrzeit': '   '},
    );

    // Bestehender Wert bleibt, der heuristische Treffer fließt nicht zurück …
    expect(ergebnis.unfallort, 'Frankfurt');
    // … und Leereingaben löschen nichts.
    expect(ergebnis.unfalluhrzeit, isNull);
    // Die Formularwerte selbst sind trotzdem vollständig gespeichert.
    expect(ergebnis.feldWerte?['Unfallort'], 'Kassel');
  });
}
