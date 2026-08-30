import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';

/// Port für den Register-Spiegel (§6.2): die Word- und PDF-Fassung des
/// Sachgebiete-Registers im eingestellten Ablageordner.
///
/// Der Export liegt im Backend und nicht hier — Word erzeugen und PDF wandeln
/// kann nur der Dienst, und vor allem muss das Schreiben nach jedem
/// Vorgangsabschluss auch dann laufen, wenn die Registerseite gar nicht offen
/// ist. Das Frontend stößt an und zeigt an.
abstract class RegisterSpiegelRepository {
  /// Schreibt den Spiegel neu. [erzwingen] schreibt auch dann, wenn sich seit
  /// dem letzten Mal nichts geändert hat — der Weg für den Knopf, hinter dem in
  /// aller Regel „die Datei ist weg oder sieht falsch aus" steht.
  Future<RegisterSpiegelErgebnis> exportiere({bool erzwingen});

  /// Was der letzte Lauf hinterlassen hat, ohne selbst zu schreiben.
  Future<RegisterSpiegelErgebnis> ladeStand();
}
