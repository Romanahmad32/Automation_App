import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/data/datasources/kanzlei_settings_datasource.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: KanzleiSettingsRepository)
class KanzleiSettingsRepositoryImpl implements KanzleiSettingsRepository {
  final KanzleiSettingsDatasource _datasource;

  KanzleiSettingsRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, KanzleiSettings>> getSettings() =>
      alsEither(() => _datasource.loadSettings(), uebersetzen: _serverFailure);

  @override
  Future<Either<Failure, KanzleiSettings>> saveSettings(
    KanzleiSettings settings,
  ) => alsEither(
    () => _datasource.saveSettings(settings),
    uebersetzen: _serverFailure,
  );

  @override
  Future<Either<Failure, KanzleiSettings>> erhoeheAuftragsnummer() => alsEither(
    () => _datasource.erhoeheAuftragsnummer(),
    uebersetzen: _serverFailure,
  );

  /// Das volle `toString()` der Ausnahme, ungekürzt (bestehendes Verhalten).
  Failure _serverFailure(Object fehler) =>
      ServerFailure(message: fehler.toString());
}
