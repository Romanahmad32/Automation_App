import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Die Vermerke „ohne Mandantenbezug" — der dritte Zustand neben zugeordnet
/// und offen.
@Injectable(as: UseCase<List<OrdnerStatus>, NoParams>)
class GetOrdnerStatus implements UseCase<List<OrdnerStatus>, NoParams> {
  final MandantenRepository _repository;

  GetOrdnerStatus(this._repository);

  @override
  Future<Either<Failure, List<OrdnerStatus>>> call(NoParams params) {
    return _repository.getOrdnerStatus();
  }
}
