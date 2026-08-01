import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<List<Akte>, NoParams>)
class GetAkten implements UseCase<List<Akte>, NoParams> {
  final MandantenRepository _repository;

  GetAkten(this._repository);

  @override
  Future<Either<Failure, List<Akte>>> call(NoParams params) {
    return _repository.getAkten();
  }
}
