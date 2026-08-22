import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';

abstract class KanzleiSettingsRepository {
  Future<Either<Failure, KanzleiSettings>> getSettings();

  Future<Either<Failure, KanzleiSettings>> saveSettings(
    KanzleiSettings settings,
  );

  /// Zählt die laufende Auftragsnummer atomar im Backend hoch (§7.1).
  Future<Either<Failure, KanzleiSettings>> erhoeheAuftragsnummer();
}
