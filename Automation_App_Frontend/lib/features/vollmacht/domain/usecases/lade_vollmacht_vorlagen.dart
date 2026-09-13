import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Holt den Stand der drei Vollmachtsvorlagen — für den Dialog und die
/// Sektion in den Einstellungen (§4.11).
@injectable
class LadeVollmachtVorlagen
    implements UseCase<VollmachtVorlagenStand, NoParams> {
  final VollmachtRepository _repository;

  LadeVollmachtVorlagen(this._repository);

  @override
  Future<Either<Failure, VollmachtVorlagenStand>> call(NoParams params) =>
      _repository.ladeVorlagen();
}
