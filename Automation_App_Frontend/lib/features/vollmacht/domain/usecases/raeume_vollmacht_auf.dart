import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Löscht die Vollmachtdateien des Vorgangs im Arbeitsordner, wenn der Dialog
/// schließt (§4.11, §8, #174) — Parameter ist die Referenz des Vorgangs. Die
/// Vollmacht wird nicht digital aufbewahrt; eine in Word geöffnete Fassung
/// soll nicht bis zur Startaufräumung nach 14 Tagen liegen bleiben.
@injectable
class RaeumeVollmachtAuf implements UseCase<void, String> {
  final VollmachtRepository _repository;

  RaeumeVollmachtAuf(this._repository);

  @override
  Future<Either<Failure, void>> call(String referenz) =>
      _repository.raeumeAuf(referenz);
}
