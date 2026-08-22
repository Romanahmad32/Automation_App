/// Port der Datensicherung (§7.2): exportiert die gesamte Datenbank des
/// Backends als eine Datei und spielt eine solche Sicherung wieder ein.
/// Einzige Quelle der Wahrheit bleibt die Datenbank im Backend; die
/// HTTP-Umsetzung liegt in der data-Schicht (`ApiBackupDatasource`).
abstract class BackupRepository {
  /// Lädt die gesamte Datenbank als eine Datei und liefert deren Bytes.
  Future<List<int>> exportDatenbank();

  /// Spielt eine zuvor exportierte Sicherung ein und liefert die
  /// Bestätigungsmeldung des Backends. Wirft bei ungültiger Datei.
  Future<String> importDatenbank(String dateipfad);
}
