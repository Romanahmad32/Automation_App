/// Wo die Aktualisierung aus der App heraus gerade steht (#196) — so, wie der
/// Dienst sie in `GET api/Aktualisierung` meldet (`zustand`).
///
/// Die Namen sind zugleich die Werte auf der Leitung; der Dienst schreibt sie
/// ausdrücklich aus, statt einen C#-Bezeichner durchzureichen.
enum AktualisierungsZustand {
  /// Noch nicht geprüft, oder die Prüfung ging nicht (kein Netz, Firewall).
  unbekannt,

  /// Geprüft, nichts Neueres.
  aktuell,

  /// Eine neue Version mit prüfbarer Setup-Datei ist da.
  verfuegbar,

  /// Der Dienst lädt die Setup-Datei.
  laedt,

  /// Geladen und geprüft — der Installer kann starten.
  bereit,

  /// Laden, Prüfen oder Starten ging nicht; den Grund nennt `meldung`.
  fehler;

  /// Ein unbekannter Wert (ein neuerer Dienst) gilt als [unbekannt]: Die
  /// Oberfläche zeigt dann keinen Hinweis, statt einen falschen.
  static AktualisierungsZustand ausText(String? text) => values.firstWhere(
    (zustand) => zustand.name == text,
    orElse: () => unbekannt,
  );
}
