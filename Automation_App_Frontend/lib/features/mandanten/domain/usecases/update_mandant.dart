import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<Mandant, Mandant>)
class UpdateMandant implements UseCase<Mandant, Mandant> {
  final MandantenRepository _repository;

  UpdateMandant(this._repository);

  @override
  Future<Either<Failure, Mandant>> call(Mandant params) {
    return _repository.updateMandant(params);
  }
}
