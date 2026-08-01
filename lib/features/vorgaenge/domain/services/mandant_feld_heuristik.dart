import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Namens-Heuristik für Mandanten-/Geschädigtenfelder: Ordnet einem frei
/// benannten Vorlagenfeld (z. B. „Straße des Mandanten") den passenden Wert
/// aus dem Mandantenregister zu — inklusive Herkunft für die Anzeige am Feld.
/// Aus dem [VorgangPrefillMatcher] herausgelöst, damit beide Bausteine kurz
/// und einzeln testbar bleiben.
class MandantFeldHeuristik {
  const MandantFeldHeuristik._();

  /// Gleiche Normalisierung wie im VorgangsdatenFieldMatcher, damit Labels
  /// nach denselben Regeln (Umlaute, Sonderzeichen) verglichen werden.
  static String normalize(String label) => label
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Liefert den Wert samt Herkunft für ein Mandantenfeld — oder null, wenn
  /// das Label keinen Mandanten betrifft oder kein Wert vorliegt. Ein
  /// [PrefillWert] mit leerem [PrefillWert.wert] bedeutet: Feld betrifft den
  /// Mandanten, hat aber bewusst keinen Wert (nicht anderweitig raten).
  static PrefillWert? wertFuer(
    String normalizedLabel,
    Mandant? mandant,
    Vorgang vorgang,
  ) {
    final label = normalizedLabel;
    final betrifftMandant =
        label.contains('mandant') ||
        label.contains('geschaedigt') ||
        label.contains('kunde');
    if (!betrifftMandant) return null;

    // Die Stammdaten kennen kein Kennzeichen des Mandanten — nicht raten
    // (sonst landete fälschlich das gegnerische Kennzeichen der Antwort im
    // Feld).
    if (label.contains('kennzeichen')) {
      return const PrefillWert('', PrefillQuelle.mandant);
    }

    PrefillWert? ausRegister(String? wert) =>
        wert == null ? null : PrefillWert(wert, PrefillQuelle.mandant);

    if (label.contains('strasse') || label.contains('hausnummer')) {
      return ausRegister(mandant?.strasseHausnummer);
    }
    if (label.contains('plz') || label.contains('postleitzahl')) {
      return ausRegister(mandant?.postleitzahl);
    }
    if (label.contains('ort') && !label.contains('vorort')) {
      return ausRegister(mandant?.ort);
    }
    if (label.contains('mail')) return ausRegister(mandant?.emailAdresse);
    if (label.contains('telefon') || label.contains('tel')) {
      return ausRegister(mandant?.telefonnummer);
    }
    if (label.contains('anschrift') || label.contains('adresse')) {
      return ausRegister(anschrift(mandant));
    }
    // Reines Namensfeld → Anzeigename des Registereintrags oder, falls keiner
    // verknüpft ist, der beim Anlegen gemerkte Namens-Schnappschuss.
    if (mandant != null) {
      return PrefillWert(mandant.anzeigename, PrefillQuelle.mandant);
    }
    final schnappschuss = vorgang.mandantName;
    return schnappschuss == null
        ? null
        : PrefillWert(schnappschuss, PrefillQuelle.vorgang);
  }

  /// Anschrift „Name, Straße, PLZ Ort" aus den Registerdaten (null, wenn kein
  /// Mandant verknüpft ist oder alle Teile leer sind).
  static String? anschrift(Mandant? mandant) {
    if (mandant == null) return null;
    final parts = [
      mandant.anzeigename,
      mandant.strasseHausnummer,
      [
        mandant.postleitzahl,
        mandant.ort,
      ].where((part) => part.trim().isNotEmpty).join(' '),
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
