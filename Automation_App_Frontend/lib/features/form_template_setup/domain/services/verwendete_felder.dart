import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';

/// Welche Felder einer Vorlage das Schreiben aus der **gerade gewählten**
/// Word-Datei überhaupt einsetzt (#82).
///
/// Eine Vorlage hat zwei Word-Dateien, aber eine Feldliste. Steht der Name
/// eines Felds nur in der anderen Datei als `{{Platzhalter}}`, verwirft die
/// Ersetzung im Backend seinen Wert wortlos — sie kennt den Namen ja gar nicht
/// und vermisst deshalb nichts. Wer ein solches Feld ausfüllt, tippt in den
/// Papierkorb.
///
/// Verglichen wird ohne Groß-/Kleinschreibung, wie die Ersetzung im Backend
/// (`RegexOptions.IgnoreCase`) und wie `FeldVorkommen` im Vorlageneditor. Wiche
/// die Prüfung davon ab, widersprächen sich Formular und Dokument.
class VerwendeteFelder {
  const VerwendeteFelder._();

  /// Der reine Namensvergleich: steht [feldname] in [aktivePlatzhalter]?
  ///
  /// Bewusst **ohne** Rückfall für die unbekannte Menge — was dann gilt,
  /// entscheidet der Aufrufer, denn für die *Pflicht* und für die
  /// *Sichtbarkeit* fällt es in entgegengesetzte Richtungen.
  static bool enthaelt(Set<String> aktivePlatzhalter, String feldname) {
    final gesucht = feldname.trim().toLowerCase();
    return aktivePlatzhalter.any(
      (name) => name.trim().toLowerCase() == gesucht,
    );
  }

  /// Ob das Schreiben [feldname] einsetzt.
  ///
  /// Ist über die Platzhalter nichts bekannt — null (keine Ableitung) oder die
  /// leere Menge (Datei nicht lesbar) —, gilt jedes Feld als verwendet. Dieser
  /// Rückfall zeigt in die **andere** Richtung als der bei der Pflicht
  /// („solange nichts bekannt ist: nicht sperren"): im Zweifel zeigen, nicht
  /// verbergen. Sonst verschluckte ein Lesefehler das ganze Formular.
  static bool wirdVerwendet(String feldname, Set<String>? aktivePlatzhalter) =>
      aktivePlatzhalter == null ||
      aktivePlatzhalter.isEmpty ||
      enthaelt(aktivePlatzhalter, feldname);

  /// [felder] geteilt in die vom Schreiben verwendeten und die übrigen — beide
  /// in der Reihenfolge der Vorlage, damit das Formular oben aussieht wie
  /// bisher, nur kürzer.
  static ({List<FieldData> verwendet, List<FieldData> uebrig}) teile(
    List<FieldData> felder,
    Set<String>? aktivePlatzhalter,
  ) {
    final verwendet = <FieldData>[];
    final uebrig = <FieldData>[];
    for (final feld in felder) {
      (wirdVerwendet(feld.label, aktivePlatzhalter) ? verwendet : uebrig).add(
        feld,
      );
    }
    return (verwendet: verwendet, uebrig: uebrig);
  }
}
