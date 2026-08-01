import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<List<Mandant>, NoParams>)
class GetMandanten implements UseCase<List<Mandant>, NoParams> {
  final MandantenRepository _repository;

  GetMandanten(this._repository);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) {
    return _repository.getMandanten();
  }
}
