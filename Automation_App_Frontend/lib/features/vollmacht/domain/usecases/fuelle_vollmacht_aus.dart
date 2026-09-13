import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Füllt die Vollmacht nur aus, damit sie in Word geöffnet werden kann (§4.11).
@injectable
class FuelleVollmachtAus
    implements UseCase<VollmachtErgebnis, VollmachtAuftrag> {
  final VollmachtRepository _repository;

  FuelleVollmachtAus(this._repository);

  @override
  Future<Either<Failure, VollmachtErgebnis>> call(VollmachtAuftrag auftrag) =>
      _repository.fuelleAus(auftrag);
}
