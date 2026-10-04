import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Die ausgefüllte Vollmacht als Seite, wie sie gedruckt würde (§4.11).
@injectable
class ErstelleVollmachtVorschau
    implements UseCase<VollmachtVorschau, VollmachtAuftrag> {
  final VollmachtRepository _repository;

  ErstelleVollmachtVorschau(this._repository);

  @override
  Future<Either<Failure, VollmachtVorschau>> call(VollmachtAuftrag auftrag) =>
      _repository.erstelleVorschau(auftrag);
}
