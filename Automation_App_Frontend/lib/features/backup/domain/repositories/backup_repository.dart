import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';

/// Port der Datensicherung (§7.2): exportiert die gesamte Datenbank des
/// Backends als eine Datei und spielt eine solche Sicherung wieder ein.
/// Einzige Quelle der Wahrheit bleibt die Datenbank im Backend; die
/// HTTP-Umsetzung liegt in der data-Schicht (`BackupRepositoryImpl`,
/// `ApiBackupDatasource`).
abstract class BackupRepository {
  /// Lädt die gesamte Datenbank und schreibt sie unter [zielPfad] — der
  /// Dateizugriff liegt bewusst hier und nicht in der Präsentation. Liefert
  /// die Bestätigungsmeldung für den Anwalt.
  Future<Either<Failure, String>> exportiereNach(String zielPfad);

  /// Spielt eine zuvor exportierte Sicherung von [dateipfad] ein und liefert
  /// die Bestätigungsmeldung des Backends.
  Future<Either<Failure, String>> importiere(String dateipfad);

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
