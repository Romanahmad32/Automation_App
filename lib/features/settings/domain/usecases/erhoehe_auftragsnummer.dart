import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:injectable/injectable.dart';

/// Zählt die laufende Auftragsnummer der Kanzlei um eins hoch und speichert sie
/// (Req. 3.2). Wird beim Abschließen eines Vorgangs aufgerufen, damit der
/// nächste Auftrag automatisch die folgende Nummer erhält. Gibt die neuen
/// Einstellungen zurück.
///
/// Bewusst eine eigene, fachlich benannte Operation statt eines rohen
/// get/save im UI: die Erhöhung ist eine atomare, an einer Stelle testbare
/// Geschäftsregel.
@injectable
class ErhoeheAuftragsnummer {
  final KanzleiSettingsRepository _repository;

  ErhoeheAuftragsnummer(this._repository);

  Future<Either<Failure, KanzleiSettings>> call() {
    // Atomar im Backend (ein Schreiber, eine Transaktion) statt get+save im
    // Frontend — schließt die frühere Read-Modify-Write-Lücke.
    return _repository.erhoeheAuftragsnummer();
  }
}
