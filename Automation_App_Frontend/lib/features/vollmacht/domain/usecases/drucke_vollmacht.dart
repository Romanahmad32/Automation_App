import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Füllt die Vollmacht aus und schickt sie an den Standarddrucker (§4.11).
///
/// Als eigene Klasse registriert statt als `UseCase<VollmachtErgebnis,
/// VollmachtAuftrag>`: `FuelleVollmachtAus` hat dieselbe Signatur, und zwei
/// Registrierungen unter einem Typ überschrieben sich in `getIt`.
@injectable
class DruckeVollmacht implements UseCase<VollmachtErgebnis, VollmachtAuftrag> {
  final VollmachtRepository _repository;

  DruckeVollmacht(this._repository);

  @override
  Future<Either<Failure, VollmachtErgebnis>> call(VollmachtAuftrag auftrag) =>
      _repository.drucke(auftrag);
}
