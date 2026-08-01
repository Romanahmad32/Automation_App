import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<KanzleiSettings, KanzleiSettings>)
class SaveKanzleiSettings implements UseCase<KanzleiSettings, KanzleiSettings> {
  final KanzleiSettingsRepository _repository;

  SaveKanzleiSettings(this._repository);

  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) {
    return _repository.saveSettings(params);
  }
}
