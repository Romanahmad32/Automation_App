import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<Mandant, VerknuepfeOrdnerParams>)
class VerknuepfeOrdnerMitMandant
    implements UseCase<Mandant, VerknuepfeOrdnerParams> {
  final MandantenRepository _repository;

  VerknuepfeOrdnerMitMandant(this._repository);

  @override
  Future<Either<Failure, Mandant>> call(VerknuepfeOrdnerParams params) {
    return _repository.verknuepfeOrdner(
      mandantId: params.mandantId,
      ordnername: params.ordnername,
    );
  }
}

class VerknuepfeOrdnerParams {
  final int mandantId;
  final String ordnername;

  const VerknuepfeOrdnerParams({
    required this.mandantId,
    required this.ordnername,
  });
}
