import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die dreiwertige Vorbelegung an [FieldData] (§5.3): **null** heißt „nie
/// angefasst" und lässt die Namensregel greifen, **lauter Nullen** heißt
/// „bewusst heute". Beide sehen im Formular gleich aus — nur der gespeicherte
/// Stand unterscheidet sie, und genau das prüfen diese Tests.
void main() {
  FieldData feld({DatumsVorbelegung? vorbelegung}) => FieldData(
    order: 0,
    label: 'Zahlungsfrist',
    required: true,
    inputType: InputType.date,
    datenquelle: FeldDatenquelle.keine,
    vorbelegung: vorbelegung,
  );

  test('ohne Vorbelegung steht der Schlüssel nicht im JSON', () {
    // So bleibt eine Vorlage, an der nie eine Vorbelegung eingestellt wurde,
    // byteidentisch zu vorher — und ein vorhandener Schlüssel heißt umgekehrt
    // immer „bewusst eingestellt".
    expect(feld().toJson().containsKey('vorbelegung'), isFalse);
  });

  test('mit Vorbelegung läuft der Stand durch das JSON zurück', () {
    final original = feld(
      vorbelegung: const DatumsVorbelegung(jahre: 1, tage: 4),
    );

    final zurueck = FieldData.fromJson(original.toJson());

    expect(zurueck.vorbelegung, const DatumsVorbelegung(jahre: 1, tage: 4));
  });

  test('lauter Nullen bleiben nach dem Rundlauf nicht-null', () {
    // Der Unterschied zu „nie angefasst": Der Anwalt hat sich für heute
    // entschieden, und die Namensregel ist damit abgeschaltet — obwohl das
    // Feld „Zahlungsfrist" heißt.
    final original = feld(vorbelegung: const DatumsVorbelegung());

    final zurueck = FieldData.fromJson(original.toJson());

    expect(zurueck.vorbelegung, isNotNull);
    expect(zurueck.vorbelegung!.istHeute, isTrue);
  });

  test('fehlt der Schlüssel im JSON, bleibt die Vorbelegung null', () {
    final zurueck = FieldData.fromJson({
      'order': 0,
      'label': 'Zahlungsfrist',
      'required': true,
      'inputType': 'date',
      'datenquelle': 'keine',
    });

    expect(zurueck.vorbelegung, isNull);
  });

  test('mitVorbelegung setzt und nimmt zurück', () {
    final gesetzt = feld().mitVorbelegung(const DatumsVorbelegung(wochen: 3));
    expect(gesetzt.vorbelegung, const DatumsVorbelegung(wochen: 3));

    // Der Grund für die eigene Methode: `copyWith(vorbelegung: null)` könnte
    // „löschen" nicht von „nicht angegeben" unterscheiden.
    expect(gesetzt.mitVorbelegung(null).vorbelegung, isNull);
  });

  test('copyWith behält die Vorbelegung', () {
    final original = feld(vorbelegung: const DatumsVorbelegung(wochen: 3));

    final geaendert = original.copyWith(required: false);

    expect(geaendert.required, isFalse);
    expect(geaendert.vorbelegung, const DatumsVorbelegung(wochen: 3));
  });
}
