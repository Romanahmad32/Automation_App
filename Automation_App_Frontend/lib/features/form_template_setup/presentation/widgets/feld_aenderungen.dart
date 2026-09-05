import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/foundation.dart';

/// Die Änderungen an einer einzelnen Feldzeile der Vorlagen-Detailseite —
/// Typ, Datenquelle, Pflichtangabe, Datums-Vorbelegung und Löschen.
///
/// Aus der Detailseite herausgezogen, wie zuvor schon `ZuordnungsAktionen`:
/// Dort sprengten sie mit der fünften Änderungsart das Zeilenbudget, und sie
/// gehören zusammen — jede ersetzt genau einen Eintrag in
/// [VorlagenBearbeitung.fields] und meldet das über [onGeaendert].
///
/// Sie arbeiten **auf** dem Stand der Seite (nicht auf einer Kopie) und werden
/// deshalb je Klick frisch gebaut; die Seite baut danach neu auf.
class FeldAenderungen {
  /// Der veränderliche Stand des Editors — Feldliste und Formular kommen von
  /// dort, statt hier ein zweites Mal zu stehen.
  final VorlagenBearbeitung bearbeitung;

  final VoidCallback onGeaendert;

  const FeldAenderungen({required this.bearbeitung, required this.onGeaendert});

  List<FieldData> get _fields => bearbeitung.fields;

  void typ(int i, InputType? wert) =>
      _ersetze(i, _fields[i].copyWith(inputType: wert));

  void datenquelle(int i, FeldDatenquelle? wert) =>
      _ersetze(i, _fields[i].copyWith(datenquelle: wert));

  void pflicht(int i, bool? wert) =>
      _ersetze(i, _fields[i].copyWith(required: wert ?? false));

  /// Über `mitVorbelegung`, nicht über `copyWith`: Nur so lässt sich die
  /// Einstellung mit null auch wieder zurücknehmen (§5.3).
  void vorbelegung(int i, DatumsVorbelegung? wert) =>
      _ersetze(i, _fields[i].mitVorbelegung(wert));

  void loeschen(int i) {
    // Zu jedem Feld gehört ein Control, dessen Schlüssel in `FieldData.label`
    // steht, solange die Seite offen ist.
    bearbeitung.formGroup.removeControl(_fields[i].label);
    _fields.removeAt(i);
    onGeaendert();
  }

  void _ersetze(int i, FieldData feld) {
    _fields[i] = feld;
    onGeaendert();
  }
}
