import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Ordnet die aus der Zentralruf-Antwort übernommenen Vorgangsdaten den
/// frei benannten Feldern einer Formularvorlage zu (Heuristik über den
/// Feldnamen). Felder ohne eindeutige Zuordnung bleiben unbefüllt — lieber
/// leer lassen als falsch vorbelegen.
class VorgangsdatenFieldMatcher {
  const VorgangsdatenFieldMatcher._();

  /// Liefert je Feldname (Label) den vorzubelegenden Wert.
  static Map<String, String> matchFields(
    Iterable<String> fieldLabels,
    ZentralrufReplyData data,
  ) {
    final result = <String, String>{};
    for (final label in fieldLabels) {
      final value = _valueFor(_normalize(label), data);
      if (value != null && value.isNotEmpty) {
        result[label] = value;
      }
    }
    return result;
  }

  static String _normalize(String label) => label
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _valueFor(String label, ZentralrufReplyData data) {
    bool has(String keyword) => label.contains(keyword);

    // Daten des Mandanten kennt die Zentralruf-Antwort nicht — solche Felder
    // nie aus ihr vorbelegen.
    if (has('mandant') || has('geschaedigt') || has('kunde')) {
      return null;
    }

    if (has('versicherungsschein') ||
        has('scheinnr') ||
        has('schadennummer') ||
        has('schadensnummer')) {
      return data.versicherungsscheinNr;
    }
    if (has('versicherungsbeginn')) {
      return data.versicherungsbeginn;
    }
    if (has('unfalldatum') ||
        has('unfalltag') ||
        has('schadentag') ||
        has('verkehrsunfall')) {
      return data.unfallDatum;
    }
    if (has('kennzeichen')) {
      // Die Antwort kennt nur das Kennzeichen des gegnerischen
      // (angefragten/haftpflichtversicherten) Fahrzeugs.
      return data.kennzeichen;
    }
    if (has('referenz') || has('aktenzeichen') || label == 'zeichen') {
      return data.referenz;
    }

    final betrifftVersicherer =
        has('versicher') || has('gegner') || has('empfaenger');
    if (betrifftVersicherer) {
      if (has('strasse')) return data.versichererStrasse;
      if (has('plz') || has('postleitzahl')) return data.versichererPlz;
      if (has('ort') && !has('vorort')) return data.versichererOrt;
      if (has('anschrift') || has('adresse')) return data.versichererAnschrift;
      if (has('mail')) return data.versichererEmail;
      if (has('telefon') || has('tel')) return data.versichererTelefon;
      if (has('fax')) return data.versichererFax;
      // Nur "Versicherer"/"Versicherung (Name)" o. Ä. → Name.
      return data.versichererName;
    }

    // Ein einzelnes E-Mail-Feld meint in diesem Workflow den Empfänger,
    // also die gegnerische Versicherung ("Per E-Mail: …").
    if (has('mail')) {
      return data.versichererEmail;
    }

    return null;
  }
}
