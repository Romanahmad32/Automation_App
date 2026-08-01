import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<Mandant, CreateMandantRequest>)
class CreateMandant implements UseCase<Mandant, CreateMandantRequest> {
  final MandantenRepository _repository;

  CreateMandant(this._repository);

  @override
  Future<Either<Failure, Mandant>> call(CreateMandantRequest params) {
    return _repository.createMandant(params);
  }
}
