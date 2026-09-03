import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';

/// Lesezugriff auf den Sachgebietskatalog des Backends (§7.1).
abstract class SachgebietRepository {
  /// Alle Katalogeinträge in Katalogreihenfolge — auch inaktive, damit der
  /// Bestand lesbar bleibt. Wirft bei Verbindungs-/Serverfehlern.
  Future<List<Sachgebiet>> ladeSachgebiete();
}
