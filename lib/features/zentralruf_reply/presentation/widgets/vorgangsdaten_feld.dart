import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Die editierbaren Felder des Vorgangsdaten-Formulars in Anzeigereihenfolge
/// (aus `VorgangsdatenForm` ausgelagert, damit Lückenfüllung und Feldliste
/// dieselbe Feld-Definition teilen).
enum VorgangsdatenFeld {
  referenz('Referenz (Ihr Zeichen)'),
  anfrageDatum('Anfrage vom'),
  kennzeichen('Gegnerisches Kennzeichen'),
  unfallDatum('Unfalldatum'),
  versichererName('Versicherer'),
  versichererStrasse('Straße'),
  versichererPlz('PLZ'),
  versichererOrt('Ort'),
  versichererTelefon('Telefon'),
  versichererFax('Fax'),
  versichererEmail('E-Mail'),
  versicherungsscheinNr('Versicherungsschein-Nr.'),
  versicherungsbeginn('Versicherungsbeginn');

  final String label;

  const VorgangsdatenFeld(this.label);

  String? wert(ZentralrufReplyData data) => switch (this) {
    VorgangsdatenFeld.referenz => data.referenz,
    VorgangsdatenFeld.anfrageDatum => data.anfrageDatum,
    VorgangsdatenFeld.kennzeichen => data.kennzeichen,
    VorgangsdatenFeld.unfallDatum => data.unfallDatum,
    VorgangsdatenFeld.versichererName => data.versichererName,
    VorgangsdatenFeld.versichererStrasse => data.versichererStrasse,
    VorgangsdatenFeld.versichererPlz => data.versichererPlz,
    VorgangsdatenFeld.versichererOrt => data.versichererOrt,
    VorgangsdatenFeld.versichererTelefon => data.versichererTelefon,
    VorgangsdatenFeld.versichererFax => data.versichererFax,
    VorgangsdatenFeld.versichererEmail => data.versichererEmail,
    VorgangsdatenFeld.versicherungsscheinNr => data.versicherungsscheinNr,
    VorgangsdatenFeld.versicherungsbeginn => data.versicherungsbeginn,
  };
}
