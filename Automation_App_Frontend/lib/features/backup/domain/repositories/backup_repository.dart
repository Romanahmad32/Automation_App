import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';

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

  /// Liegt am anderen Arbeitsplatz ein neuerer Stand — und wie ist die letzte
  /// automatische Sicherung ausgegangen? Wird beim Start abgefragt, bevor die
  /// Oberfläche aufgeht.
  Future<UebergabeStand> uebergabeStand();

  /// Übernimmt den angebotenen Stand und liefert die Meldung des Backends.
  /// Ersetzt den bisherigen Bestand — deshalb nur auf ausdrücklichen Auftrag.
  Future<String> uebernehmeStand();

  /// Bestätigt, dass die Meldung über eine misslungene automatische Sicherung
  /// gelesen wurde. Ohne das stünde sie bei jedem Start wieder da.
  Future<void> quittiereSicherungsfehler();
}
