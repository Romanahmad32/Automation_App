import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Fragt den Windows-Standarddrucker ab — die Zeile über den Knöpfen des
/// Vollmacht-Dialogs (§4.11).
@injectable
class LadeVollmachtDrucker implements UseCase<VollmachtDrucker, NoParams> {
  final VollmachtRepository _repository;

  LadeVollmachtDrucker(this._repository);

  @override
  Future<Either<Failure, VollmachtDrucker>> call(NoParams params) =>
      _repository.ladeDrucker();
}
