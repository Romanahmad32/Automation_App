import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/services/vorgangsdaten_field_matcher.dart';

/// Ordnet die in einem [Vorgang] gebündelten Daten den frei benannten Feldern
/// einer Formularvorlage zu — die Phase-4-Erweiterung des
/// [VorgangsdatenFieldMatcher]:
///
/// * Mandant-/Geschädigten-/Kundenfelder kommen aus dem verknüpften [Mandant]
///   (bzw. dem Namens-Schnappschuss des Vorgangs, wenn kein Registereintrag
///   vorliegt),
/// * das Rechtsgebiet aus dem Vorgang,
/// * alle übrigen Felder (Versicherer, Unfalldatum, Referenz …) aus der
///   übernommenen Zentralruf-Antwort über die bewährte Antwort-Heuristik.
///
/// Felder ohne eindeutige Zuordnung bleiben leer — lieber unbefüllt als falsch
/// vorbelegt (Req. 3.4). So zieht der Word-Assistent Mandant + Antwort +
/// Rechtsgebiet direkt aus dem gewählten Vorgang, statt sie erneut zu erfassen.
class VorgangPrefillMatcher {
  const VorgangPrefillMatcher._();

  /// Liefert je Feldname (Label) den vorzubelegenden Wert.
  static Map<String, String> matchFields(
    Iterable<String> fieldLabels,
    Vorgang vorgang, {
    Mandant? mandant,
  }) {
    final labels = fieldLabels.toList();

    // Versicherer-/Antwortfelder über die bewährte Antwort-Heuristik. Sie lässt
    // Mandant-/Geschädigtenfelder bewusst leer, sodass es hier keine Kollision
    // mit der Mandanten-Vorbelegung gibt.
    final antwort = vorgang.antwort;
    final ausAntwort = antwort == null
        ? const <String, String>{}
        : VorgangsdatenFieldMatcher.matchFields(labels, antwort);

    final result = <String, String>{};
    for (final label in labels) {
      final normalized = _normalize(label);

      final mandantWert = _mandantValue(normalized, mandant, vorgang);
      if (mandantWert != null && mandantWert.isNotEmpty) {
        result[label] = mandantWert;
        continue;
      }

      final rechtsgebietWert = _rechtsgebietValue(normalized, vorgang);
      if (rechtsgebietWert != null && rechtsgebietWert.isNotEmpty) {
        result[label] = rechtsgebietWert;
        continue;
      }

      final antwortWert = ausAntwort[label];
      if (antwortWert != null && antwortWert.isNotEmpty) {
        result[label] = antwortWert;
      }
    }
    return result;
  }

  // Gleiche Normalisierung wie im VorgangsdatenFieldMatcher, damit Labels nach
  // denselben Regeln (Umlaute, Sonderzeichen) verglichen werden.
  static String _normalize(String label) => label
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _mandantValue(
    String label,
    Mandant? mandant,
    Vorgang vorgang,
  ) {
    final betrifftMandant =
        label.contains('mandant') ||
        label.contains('geschaedigt') ||
        label.contains('kunde');
    if (!betrifftMandant) return null;

    // Die Stammdaten kennen kein Kennzeichen des Mandanten — nicht raten (sonst
    // landete fälschlich das gegnerische Kennzeichen der Antwort im Feld).
    if (label.contains('kennzeichen')) return '';

    if (label.contains('strasse') || label.contains('hausnummer')) {
      return mandant?.strasseHausnummer;
    }
    if (label.contains('plz') || label.contains('postleitzahl')) {
      return mandant?.postleitzahl;
    }
    if (label.contains('ort') && !label.contains('vorort')) {
      return mandant?.ort;
    }
    if (label.contains('mail')) return mandant?.emailAdresse;
    if (label.contains('telefon') || label.contains('tel')) {
      return mandant?.telefonnummer;
    }
    if (label.contains('anschrift') || label.contains('adresse')) {
      return _anschrift(mandant);
    }
    // Reines Namensfeld → Anzeigename des Registereintrags oder, falls keiner
    // verknüpft ist, der beim Anlegen gemerkte Namens-Schnappschuss.
    return mandant?.anzeigename ?? vorgang.mandantName;
  }

  static String? _anschrift(Mandant? mandant) {
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

  static String? _rechtsgebietValue(String label, Vorgang vorgang) {
    if (label.contains('rechtsgebiet') || label.contains('sachgebiet')) {
      return vorgang.rechtsgebiet.displayName;
    }
    return null;
  }
}
