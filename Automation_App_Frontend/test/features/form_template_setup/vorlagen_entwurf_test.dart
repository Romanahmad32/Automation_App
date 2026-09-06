import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_entwurf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Vergleich, an dem die Rückfrage beim Verlassen des Vorlageneditors
/// hängt (§1.3, #104). Er muss **jede** Einstellung sehen, die der Anwalt
/// treffen kann — jede, die er hier nicht sieht, geht beim Verlassen wortlos
/// verloren.
void main() {
  /// Ein Feld so, wie es auf der offenen Detailseite steht: In `label` liegt
  /// der Control-Schlüssel, der Name im Formular (siehe `FALLSTRICKE.md`).
  FieldData feld(
    int index, {
    InputType inputType = InputType.text,
    FeldDatenquelle datenquelle = FeldDatenquelle.keine,
    bool pflicht = true,
    DatumsVorbelegung? vorbelegung,
  }) => FieldData(
    order: index,
    label: 'field_$index',
    required: pflicht,
    inputType: inputType,
    datenquelle: datenquelle,
    vorbelegung: vorbelegung,
  );

  VorlagenEntwurf entwurf({
    String? vorlagenname = 'Anspruchsschreiben',
    String? pfadOhne = 'HGn.docx',
    String? pfadMit,
    List<FieldData> fields = const [],
    Map<String, String?> namen = const {},
  }) => VorlagenEntwurf.aufnehmen(
    vorlagenname: vorlagenname,
    pfadOhneAuflistung: pfadOhne,
    pfadMitAuflistung: pfadMit,
    fields: fields,
    feldname: (controlKey) => namen[controlKey],
  );

  test('derselbe Stand ist gleich', () {
    final fields = [feld(0), feld(1, inputType: InputType.date)];
    const namen = {'field_0': 'Kennzeichen', 'field_1': 'Zahlungsfrist'};

    expect(
      entwurf(fields: fields, namen: namen),
      entwurf(fields: fields, namen: namen),
    );
  });

  test('der Vorlagenname zählt', () {
    expect(
      entwurf(vorlagenname: 'Mahnung'),
      isNot(entwurf(vorlagenname: 'Anspruchsschreiben')),
    );
  });

  test('beide Word-Pfade zählen', () {
    expect(entwurf(pfadOhne: 'Anders.docx'), isNot(entwurf()));
    expect(entwurf(pfadMit: 'MitTabelle.docx'), isNot(entwurf()));
  });

  test('null und der leere Text sind derselbe leere Stand', () {
    // Sonst zählte schon das Öffnen eines nie befüllten Feldes als Änderung,
    // sobald reactive_forms einmal einen Wert gesehen hat.
    expect(entwurf(vorlagenname: null), entwurf(vorlagenname: ''));
    expect(entwurf(pfadMit: null), entwurf(pfadMit: ''));
    expect(
      entwurf(fields: [feld(0)], namen: const {'field_0': null}),
      entwurf(fields: [feld(0)], namen: const {'field_0': ''}),
    );
  });

  test(
    'der Feldname wird aufgelöst, nicht der Control-Schlüssel verglichen',
    () {
      // Beide Stände tragen dieselben Schlüssel `field_0`; unterschiedlich ist
      // nur, was im Formular darunter steht. Ein Vergleich über die Schlüssel
      // sähe hier keinen Unterschied — und das Umbenennen eines Feldes ginge
      // beim Verlassen verloren.
      expect(
        entwurf(fields: [feld(0)], namen: const {'field_0': 'Unfalldatum'}),
        isNot(
          entwurf(fields: [feld(0)], namen: const {'field_0': 'Unfalltag'}),
        ),
      );
    },
  );

  test('jede Einstellung einer Feldzeile zählt', () {
    const namen = {'field_0': 'Zahlungsfrist'};
    final ausgang = entwurf(fields: [feld(0)], namen: namen);

    // Genau die fünf Angaben, die `formGroup.dirty` bis auf den Namen alle
    // übersieht.
    expect(
      entwurf(
        fields: [feld(0, inputType: InputType.date)],
        namen: namen,
      ),
      isNot(ausgang),
    );
    expect(
      entwurf(
        fields: [feld(0, datenquelle: FeldDatenquelle.mandantName)],
        namen: namen,
      ),
      isNot(ausgang),
    );
    expect(
      entwurf(fields: [feld(0, pflicht: false)], namen: namen),
      isNot(ausgang),
    );
    expect(
      entwurf(
        fields: [feld(0, vorbelegung: const DatumsVorbelegung(wochen: 2))],
        namen: namen,
      ),
      isNot(ausgang),
    );
  });

  test('„nie eingestellt" und „bewusst heute" sind zwei Stände', () {
    // Dieselbe Unterscheidung wie in `FieldData` (§5.3): null heißt
    // Namensregel, lauter Nullen heißt abgeschaltete Namensregel.
    const namen = {'field_0': 'Zahlungsfrist'};
    expect(
      entwurf(
        fields: [feld(0, vorbelegung: const DatumsVorbelegung())],
        namen: namen,
      ),
      isNot(entwurf(fields: [feld(0)], namen: namen)),
    );
  });

  test('die Reihenfolge der Felder zählt', () {
    const namen = {'field_0': 'Kennzeichen', 'field_1': 'Unfalldatum'};
    final vorwaerts = entwurf(fields: [feld(0), feld(1)], namen: namen);
    final rueckwaerts = entwurf(fields: [feld(1), feld(0)], namen: namen);

    // Umsortieren ändert nur `fields`; die FormGroup bleibt Zeichen für
    // Zeichen dieselbe.
    expect(rueckwaerts, isNot(vorwaerts));
  });

  test('ein zusätzliches Feld zählt', () {
    const namen = {'field_0': 'Kennzeichen', 'field_1': 'Unfalldatum'};
    expect(
      entwurf(fields: [feld(0), feld(1)], namen: namen),
      isNot(entwurf(fields: [feld(0)], namen: namen)),
    );
  });
}
