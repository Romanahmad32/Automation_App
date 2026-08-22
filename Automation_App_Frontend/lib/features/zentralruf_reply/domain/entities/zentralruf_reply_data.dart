import 'package:equatable/equatable.dart';

/// Aus der Zentralruf-Antwortmail extrahierte, für das Anspruchsschreiben
/// relevante Vorgangsdaten. Nicht erkannte Werte sind null.
class ZentralrufReplyData extends Equatable {
  final String? referenz;

  /// Bestandteile der Referenz nach dem Schema "Nr/Jahr Abteilung_Kennzeichen"
  /// (null, wenn die Referenz dem Schema nicht folgt).
  final String? referenzAuftragsnummer;
  final String? referenzJahr;
  final String? referenzAbteilung;
  final String? referenzKennzeichen;

  final String? anfrageDatum;

  /// Gegnerisches Kennzeichen, vom Backend normalisiert (z. B. "GG-XY 123").
  final String? kennzeichen;
  final String? unfallDatum;
  final String? versichererName;
  final String? versichererStrasse;
  final String? versichererPlz;
  final String? versichererOrt;
  final String? versichererTelefon;
  final String? versichererFax;
  final String? versichererEmail;
  final String? versicherungsscheinNr;
  final String? versicherungsbeginn;

  /// True, wenn der Zentralruf ausdrücklich keinen Versicherer ermitteln
  /// konnte (Negativ-Antwort).
  final bool keinVersichererErmittelt;

  /// True, wenn die Mail nur eine Zwischennachricht ist (Auskunft nicht
  /// sofort möglich, z. B. manuelle Prüfung / ausländisches Kennzeichen);
  /// die endgültige Antwort folgt in einer weiteren Mail.
  final bool zwischennachricht;

  const ZentralrufReplyData({
    this.referenz,
    this.referenzAuftragsnummer,
    this.referenzJahr,
    this.referenzAbteilung,
    this.referenzKennzeichen,
    this.anfrageDatum,
    this.kennzeichen,
    this.unfallDatum,
    this.versichererName,
    this.versichererStrasse,
    this.versichererPlz,
    this.versichererOrt,
    this.versichererTelefon,
    this.versichererFax,
    this.versichererEmail,
    this.versicherungsscheinNr,
    this.versicherungsbeginn,
    this.keinVersichererErmittelt = false,
    this.zwischennachricht = false,
  });

  factory ZentralrufReplyData.fromJson(Map<String, dynamic> json) {
    return ZentralrufReplyData(
      referenz: json['referenz'] as String?,
      referenzAuftragsnummer: json['referenzAuftragsnummer'] as String?,
      referenzJahr: json['referenzJahr'] as String?,
      referenzAbteilung: json['referenzAbteilung'] as String?,
      referenzKennzeichen: json['referenzKennzeichen'] as String?,
      anfrageDatum: json['anfrageDatum'] as String?,
      kennzeichen: json['kennzeichen'] as String?,
      unfallDatum: json['unfallDatum'] as String?,
      versichererName: json['versichererName'] as String?,
      versichererStrasse: json['versichererStrasse'] as String?,
      versichererPlz: json['versichererPlz'] as String?,
      versichererOrt: json['versichererOrt'] as String?,
      versichererTelefon: json['versichererTelefon'] as String?,
      versichererFax: json['versichererFax'] as String?,
      versichererEmail: json['versichererEmail'] as String?,
      versicherungsscheinNr: json['versicherungsscheinNr'] as String?,
      versicherungsbeginn: json['versicherungsbeginn'] as String?,
      keinVersichererErmittelt:
          json['keinVersichererErmittelt'] as bool? ?? false,
      zwischennachricht: json['zwischennachricht'] as bool? ?? false,
    );
  }

  /// Für die lokale Persistenz der übernommenen Vorgangsdaten (§3:
  /// "speichern" — die Antwort kommt oft erst Tage nach der Anfrage).
  Map<String, dynamic> toJson() => {
    'referenz': referenz,
    'referenzAuftragsnummer': referenzAuftragsnummer,
    'referenzJahr': referenzJahr,
    'referenzAbteilung': referenzAbteilung,
    'referenzKennzeichen': referenzKennzeichen,
    'anfrageDatum': anfrageDatum,
    'kennzeichen': kennzeichen,
    'unfallDatum': unfallDatum,
    'versichererName': versichererName,
    'versichererStrasse': versichererStrasse,
    'versichererPlz': versichererPlz,
    'versichererOrt': versichererOrt,
    'versichererTelefon': versichererTelefon,
    'versichererFax': versichererFax,
    'versichererEmail': versichererEmail,
    'versicherungsscheinNr': versicherungsscheinNr,
    'versicherungsbeginn': versicherungsbeginn,
    'keinVersichererErmittelt': keinVersichererErmittelt,
    'zwischennachricht': zwischennachricht,
  };

  /// Vollständige Anschrift des Versicherers inkl. Name (für ein einzelnes
  /// Adressfeld, das den kompletten Empfängerblock aufnimmt).
  String? get versichererAnschrift {
    final parts = [
      versichererName,
      versichererStrasse,
      [versichererPlz, versichererOrt].whereType<String>().join(' '),
    ].where((part) => part != null && part.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Anschrift des Versicherers OHNE Namen (Straße, PLZ Ort) — für ein reines
  /// „Adresse"-Feld, wenn der Name in einem separaten Feld steht (sonst stünde
  /// der Versicherername doppelt im Brief).
  String? get versichererAdresseOhneName {
    final parts = [
      versichererStrasse,
      [versichererPlz, versichererOrt].whereType<String>().join(' '),
    ].where((part) => part != null && part.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  List<Object?> get props => [
    referenz,
    referenzAuftragsnummer,
    referenzJahr,
    referenzAbteilung,
    referenzKennzeichen,
    anfrageDatum,
    kennzeichen,
    unfallDatum,
    versichererName,
    versichererStrasse,
    versichererPlz,
    versichererOrt,
    versichererTelefon,
    versichererFax,
    versichererEmail,
    versicherungsscheinNr,
    versicherungsbeginn,
    keinVersichererErmittelt,
    zwischennachricht,
  ];
}

/// Eingabe für die Antwort-Auswertung: entweder eingefügter/geladener Text
/// oder eine komplette .eml-Datei (Base64), die das Backend MIME-dekodiert.
class ZentralrufReplyInput extends Equatable {
  final String? emailText;
  final String? emailFileBase64;

  const ZentralrufReplyInput.text(String this.emailText)
    : emailFileBase64 = null;

  const ZentralrufReplyInput.emlBase64(String this.emailFileBase64)
    : emailText = null;

  @override
  List<Object?> get props => [emailText, emailFileBase64];
}

/// Parse-Ergebnis inkl. der vom Backend gemeldeten fehlenden Felder
/// (§4.3: kein stilles Auslassen von Werten) und Warnungen
/// (z. B. Kennzeichen passt nicht zur Referenz, Negativ-Antwort).
class ZentralrufReplyParseResult extends Equatable {
  final ZentralrufReplyData data;
  final List<String> missingFields;
  final List<String> warnings;

  const ZentralrufReplyParseResult({
    required this.data,
    required this.missingFields,
    this.warnings = const [],
  });

  @override
  List<Object?> get props => [data, missingFields, warnings];
}
