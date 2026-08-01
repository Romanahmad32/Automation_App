import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<void, DeleteMandantParams>)
class DeleteMandant implements UseCase<void, DeleteMandantParams> {
  final MandantenRepository _repository;

  DeleteMandant(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteMandantParams params) {
    return _repository.deleteMandant(params.id);
  }
}

class DeleteMandantParams {
  final int id;

  const DeleteMandantParams(this.id);
}
