/// Welche Ursache der Dialog „App aktualisieren“ im Fehlerfall (2d) nennt —
/// so, wie der Dienst sie in `fehlerArt` meldet (`AktualisierungsStandDto`,
/// nur bei `zustand == fehler` gesetzt).
///
/// Die abgenommene Gestalt sieht für die zwei häufigen Fälle je einen kurzen,
/// ruhigen Satz vor; alles andere (Festplatte voll, Start verweigert, Setup
/// oder Prüfsumme fehlen bei GitHub, Datei verschwunden) zeigt den Satz des
/// Dienstes selbst (`meldung`). Den Wortlaut dieses Satzes deutet das
/// Frontend nicht — die Ursache steht im Vertrag.
///
/// Die Namen sind zugleich die Werte auf der Leitung; der Dienst schreibt sie
/// ausdrücklich aus, statt einen C#-Bezeichner durchzureichen.
enum AktualisierungsFehlerArt {
  /// Abgerissen oder steckengeblieben: „Meist fehlt nur kurz die
  /// Internetverbindung.“
  verbindung,

  /// Größe oder Prüfsumme stimmten nicht, die Datei ist gelöscht: „Die Datei
  /// kam nicht vollständig an und wird nicht verwendet.“
  pruefung,

  /// Alles andere — dann gilt der Satz des Dienstes.
  sonstig;

  /// Ohne Wert (kein Fehler) `null`. Ein unbekannter Wert (ein neuerer
  /// Dienst) gilt als [sonstig]: Dann steht der Satz des Dienstes da, also nie
  /// eine falsche Ursache.
  static AktualisierungsFehlerArt? ausText(String? text) => text == null
      ? null
      : values.firstWhere((art) => art.name == text, orElse: () => sonstig);
}
