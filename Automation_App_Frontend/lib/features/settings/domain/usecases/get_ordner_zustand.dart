import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:injectable/injectable.dart';

/// Holt den Zustand der fünf Ordner (#103) für die Anzeige im Reiter
/// „Kanzlei". Nur lesend — geschrieben wird ausschließlich über
/// `SaveKanzleiSettings`.
@Injectable(as: UseCase<List<OrdnerZustand>, NoParams>)
class GetOrdnerZustand implements UseCase<List<OrdnerZustand>, NoParams> {
  final KanzleiSettingsRepository _repository;

  GetOrdnerZustand(this._repository);

  @override
  Future<Either<Failure, List<OrdnerZustand>>> call(NoParams params) {
    return _repository.ordnerZustand();
  }
}
