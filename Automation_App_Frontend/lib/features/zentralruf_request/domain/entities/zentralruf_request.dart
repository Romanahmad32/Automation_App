class ZentralrufRequest {
  /// Laufende Auftragsnummer, z. B. 84.
  final int auftragsnummer;

  /// Zweistelliges Auftragsjahr, z. B. 26. 0 = aktuelles Jahr.
  final int auftragsjahr;

  /// Abteilung, z. B. "C03".
  final String abteilung;

  /// Amtliches Kennzeichen des Unfallgegners.
  final String kennzeichenSchaediger;

  /// Unfalldatum.
  final DateTime schadentag;

  /// Optionale, vom Anwender überschriebene Referenz. Null/leer = Backend baut die
  /// Referenz aus Auftragsnummer/-jahr, Abteilung und Kennzeichen zusammen.
  final String? referenz;

  final ZentralrufGeschaedigter? geschaedigter;

  /// Kanzlei-/Anfragerdaten aus den App-Einstellungen. Null = Backend nutzt seine
  /// Fallback-Werte aus appsettings.json.
  final ZentralrufAnfrager? anfrager;

  const ZentralrufRequest({
    required this.auftragsnummer,
    this.auftragsjahr = 0,
    required this.abteilung,
    required this.kennzeichenSchaediger,
    required this.schadentag,
    this.referenz,
    this.geschaedigter,
    this.anfrager,
  });

  ZentralrufRequest copyWith({ZentralrufAnfrager? anfrager}) {
    return ZentralrufRequest(
      auftragsnummer: auftragsnummer,
      auftragsjahr: auftragsjahr,
      abteilung: abteilung,
      kennzeichenSchaediger: kennzeichenSchaediger,
      schadentag: schadentag,
      referenz: referenz,
      geschaedigter: geschaedigter,
      anfrager: anfrager ?? this.anfrager,
    );
  }
}

class ZentralrufAnfrager {
  final String personentyp;
  final String name;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String emailAdresse;
  final String telefonnummer;

  const ZentralrufAnfrager({
    this.personentyp = '',
    this.name = '',
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.emailAdresse = '',
    this.telefonnummer = '',
  });
}

class ZentralrufGeschaedigter {
  final String name;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String kennzeichen;

  const ZentralrufGeschaedigter({
    required this.name,
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.kennzeichen = '',
  });
}
