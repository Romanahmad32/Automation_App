import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Die Historie der herausgegebenen Arbeitspakete — wie viele draußen sind,
/// wie weit jedes gediehen ist, welches noch offen ist.
@Injectable(as: UseCase<List<ImportPaket>, NoParams>)
class GetImportPakete implements UseCase<List<ImportPaket>, NoParams> {
  final MandantenRepository _repository;

  GetImportPakete(this._repository);

  @override
  Future<Either<Failure, List<ImportPaket>>> call(NoParams params) {
    return _repository.getImportPakete();
  }
}
