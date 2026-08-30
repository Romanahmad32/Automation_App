import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';

/// Rückfluss der Wizard-Eingaben in den Vorgang — das Gegenstück zum
/// [VorgangPrefillMatcher]: Was der Anwalt beim Erzeugen des Dokuments
/// ausgefüllt hat, wird am Vorgang gespeichert, damit die App es beim nächsten
/// Schreiben (Korrektur, Folgeschreiben) wiederverwendet statt neu zu fragen.
///
/// * Alle Formularwerte landen als Ganzes in [Vorgang.feldWerte] (und die
///   Schadensaufstellung in [Vorgang.schadensaufstellung]).
/// * Felder mit **explizit** zugeordneter [FeldDatenquelle] fließen zusätzlich
///   in die entsprechenden Vorgangsfelder zurück (Unfallort, Uhrzeit,
///   Polizei-Nr., Unfalldatum, Mandanten-Kennzeichen) — der zuletzt vom Anwalt
///   bestätigte Wert gewinnt. Heuristisch gemappte Felder werden bewusst nicht
///   zurückgeschrieben (lieber gar nicht als falsch, §1.3); das aus der
///   Referenz abgeleitete Gegner-Kennzeichen bleibt ebenfalls unberührt.
/// * Ein offener [Vorgang.entwurf] fällt dabei weg: Bestätigt schlägt
///   angefangen, und was hier ankommt, ist bestätigt.
class VorgangRueckfluss {
  const VorgangRueckfluss._();

  /// Liefert den Vorgang mit übernommenen Wizard-Ergebnissen.
  static Vorgang uebernehmeWizardErgebnis(
    Vorgang vorgang, {
    required List<FieldData> fields,
    required Map<String, String> formData,
    DamageListing? schadensaufstellung,
  }) {
    String? wert(FeldDatenquelle quelle) {
      for (final field in fields) {
        if (field.datenquelle != quelle) continue;
        final eingabe = formData[field.label]?.trim();
        if (eingabe != null && eingabe.isNotEmpty) return eingabe;
      }
      return null;
    }

    return vorgang.copyWith(
      feldWerte: Map.unmodifiable(formData),
      schadensaufstellung: schadensaufstellung,
      // Aus dem Entwurf ist ein bestätigter Stand geworden — er hat sich
      // erledigt. Bliebe er stehen, böte die Leiste beim nächsten Einstieg
      // einen älteren Stand gegen die gerade bestätigten Werte an, und der
      // Anwalt müsste raten, welcher der neuere ist.
      entwurf: () => null,
      unfallDatum: wert(FeldDatenquelle.unfalldatum),
      unfallort: wert(FeldDatenquelle.unfallort),
      unfalluhrzeit: wert(FeldDatenquelle.unfalluhrzeit),
      polizeiVorgangsnummer: wert(FeldDatenquelle.polizeiVorgangsnummer),
      geschaedigtenKennzeichen: wert(FeldDatenquelle.kennzeichenMandant),
    );
  }
}
