import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/cubit/backup_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Steuert Export und Import der Datenbank und meldet Fortschritt bzw. Ergebnis
/// an die Datensicherungs-Ansicht. Die Auswahl der Dateipfade (native Dialoge)
/// bleibt in der UI; Dateizugriff und Fehlerübersetzung liegen im Repository.
@injectable
class BackupCubit extends Cubit<BackupState> {
  final BackupRepository _repository;

  BackupCubit(this._repository) : super(const BackupIdle());

  /// Holt die Sicherung vom Backend und schreibt sie an den gewählten Zielpfad.
  Future<void> exportiere(String zielPfad) async {
    emit(const BackupBusy('Sicherung wird erstellt …'));
    final ergebnis = await _repository.exportiereNach(zielPfad);
    emit(switch (ergebnis) {
      Right(value: final meldung) => BackupErfolg(meldung),
      Left(value: final fehler) => BackupFehler(fehler.message),
    });
  }

  /// Spielt die gewählte Sicherungsdatei ein (überschreibt alle Daten).
  Future<void> importiere(String dateipfad) async {
    emit(const BackupBusy('Sicherung wird eingespielt …'));
    final ergebnis = await _repository.importiere(dateipfad);
    emit(switch (ergebnis) {
      Right(value: final meldung) => BackupErfolg(meldung),
      Left(value: final fehler) => BackupFehler(fehler.message),
    });
  }
}
