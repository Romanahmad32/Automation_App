import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/word_automation/domain/services/ausgangs_belegung.dart';
import 'package:flutter_test/flutter_test.dart';

/// #133 Mangel 2: Ein leeres Datumsfeld startet nicht leer, sondern mit dem
/// heutigen Datum (`FormTemplateBuilder`). [AusgangsBelegung] rechnet genau
/// diesen Vorschlag in die Ausgangsbelegung ein — sonst hielte der
/// Abweichungsvergleich ihn für eine Eingabe des Anwalts.
void main() {
  FieldData textFeld(String label) => FieldData(
    order: 0,
    label: label,
    required: false,
    inputType: InputType.text,
  );

  FieldData datumsFeld(String label, {DatumsVorbelegung? vorbelegung}) =>
      FieldData(
        order: 0,
        label: label,
        required: false,
        inputType: InputType.date,
        vorbelegung: vorbelegung,
      );

  final heute = deutschesDatum(DateTime.now());

  test('ein Textfeld ohne Vorbelegung bleibt aussen vor', () {
    final belegung = AusgangsBelegung.vollstaendig(
      fields: [textFeld('Aktenzeichen')],
      initialValues: const {},
      aktivePlatzhalter: null,
    );

    expect(belegung, isEmpty);
  });

  test('ein leeres Datumsfeld bekommt den Vorschlag mit heutigem Datum', () {
    final belegung = AusgangsBelegung.vollstaendig(
      fields: [datumsFeld('Unfalldatum')],
      initialValues: const {},
      aktivePlatzhalter: null,
    );

    expect(belegung, {'Unfalldatum': heute});
  });

  test('eine echte Vorbelegung hat Vorrang vor dem Datumsvorschlag', () {
    final belegung = AusgangsBelegung.vollstaendig(
      fields: [datumsFeld('Unfalldatum')],
      initialValues: const {'Unfalldatum': '01.01.2020'},
      aktivePlatzhalter: null,
    );

    expect(belegung, {'Unfalldatum': '01.01.2020'});
  });

  test('ein eingeklapptes Datumsfeld bekommt keinen Vorschlag', () {
    // #82: Ohne Control gäbe es für den Wert keine Anzeige und keine
    // Korrekturmöglichkeit — genau das schließt `FormTemplateBuilder` beim
    // Aufbau der Werte selbst aus.
    final belegung = AusgangsBelegung.vollstaendig(
      fields: [datumsFeld('Unfalldatum')],
      initialValues: const {},
      aktivePlatzhalter: const {'Ein anderes Feld'},
    );

    expect(belegung, isEmpty);
  });

  test('die eingestellte Vorbelegung geht vor der Namensregel', () {
    final belegung = AusgangsBelegung.vollstaendig(
      fields: [
        datumsFeld('Zahlungsfrist', vorbelegung: const DatumsVorbelegung()),
      ],
      initialValues: const {},
      aktivePlatzhalter: null,
    );

    // Ohne die eingestellte Vorbelegung (bewusst „heute") griffe die
    // Namensregel und läge bei 5 Wochen statt heute.
    expect(belegung, {'Zahlungsfrist': heute});
  });

  test('ohne eigene Vorbelegung greift die Namensregel', () {
    final belegung = AusgangsBelegung.vollstaendig(
      fields: [datumsFeld('Zahlungsfrist')],
      initialValues: const {},
      aktivePlatzhalter: null,
    );

    expect(
      belegung['Zahlungsfrist'],
      deutschesDatum(
        const DatumsVorbelegung(wochen: 5).anwendenAuf(DateTime.now()),
      ),
    );
  });
}
