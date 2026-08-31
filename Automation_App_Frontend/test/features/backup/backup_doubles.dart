import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';

/// Ein Backup-Port, der antwortet, ohne einen Dienst zu brauchen — und der
/// mitzählt, was er gefragt wurde. Beim Start hängt genau daran die Zusage von
/// §7.2: „Eigenen Stand behalten" darf **nichts** einspielen.
class BackupDouble implements BackupRepository {
  BackupDouble(this._stand, {this.standWirft = false});

  final UebergabeStand _stand;

  /// Simuliert einen Dienst, der die Auskunft nicht liefert.
  final bool standWirft;

  int uebernahmen = 0;
  int quittungen = 0;

  /// Lässt die Übernahme scheitern, um den Fehlerweg zu prüfen.
  Object? uebernahmeWirft;

  @override
  Future<UebergabeStand> uebergabeStand() async {
    if (standWirft) throw StateError('Dienst antwortet nicht');
    return _stand;
  }

  @override
  Future<String> uebernehmeStand() async {
    uebernahmen++;
    final fehler = uebernahmeWirft;
    if (fehler != null) throw fehler;
    return 'Stand von BUERO-PC übernommen.';
  }

  @override
  Future<void> quittiereSicherungsfehler() async => quittungen++;

  @override
  Future<List<int>> exportDatenbank() async => const [];

  @override
  Future<String> importDatenbank(String dateipfad) async => '';
}
