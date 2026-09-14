import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/verwendete_felder.dart';

/// Was das Ausfüllformular **ohne jede Eingabe** zeigen würde: die Vorbelegung
/// aus dem Bestand (Zentralruf-Antwort, Mandant, …), ergänzt um die einzige
/// weitere automatische Belegung — den Datumsvorschlag, mit dem
/// `FormTemplateBuilder` ein leeres Datumsfeld füllt (#133 Mangel 2).
///
/// **Eine Quelle für beide Seiten.** Ohne sie kennte der Abweichungsvergleich
/// in `ausfuell_formular.dart` den Datumsvorschlag nicht und hielte ihn für
/// eine Eingabe des Anwalts — der „Zurücksetzen"-Link erschiene, ohne dass er
/// etwas getippt hätte, und das Feld landete unnötig im Entwurf.
class AusgangsBelegung {
  const AusgangsBelegung._();

  /// [initialValues] samt Datumsvorschlag für jedes Datumsfeld, das dort noch
  /// keinen Wert hat und das Schreiben tatsächlich einsetzt.
  ///
  /// Ein eingeklapptes Feld (#82, [VerwendeteFelder.wirdVerwendet]) bekommt
  /// **keinen** Vorschlag: `FormTemplateBuilder` baut für es kein Control, ein
  /// Wert hier bliebe unsichtbar und unkorrigierbar — genau der Fall, den
  /// [FormTemplateBuilder] beim Aufbau der Werte selbst ausschließt.
  static Map<String, String> vollstaendig({
    required List<FieldData> fields,
    required Map<String, String> initialValues,
    required Set<String>? aktivePlatzhalter,
  }) => {
    ...initialValues,
    for (final feld in fields)
      if (!initialValues.containsKey(feld.label) &&
          feld.inputType == InputType.date &&
          VerwendeteFelder.wirdVerwendet(feld.label, aktivePlatzhalter))
        feld.label: deutschesDatum(datumsVorschlag(feld)),
  };

  /// Der vorgeschlagene Wert für ein leeres Datumsfeld: die am Feld
  /// eingestellte [DatumsVorbelegung], sonst die Namensregel als Rückfall —
  /// Einzelheiten und die Kalenderrechnung dahinter stehen an [DatumsVorbelegung].
  static DateTime datumsVorschlag(FieldData feld) =>
      (feld.vorbelegung ?? DatumsVorbelegung.ausFeldname(feld.label))
          .anwendenAuf(DateTime.now());
}
