import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Nimmt ein versehentlich herausgegebenes, noch offenes Arbeitspaket zurück
/// — für den Klick daneben auf „Arbeitspaket holen". Rührt keinen Ordner an,
/// entfernt nur die Buchführungszeile.
@Injectable(as: UseCase<void, LoescheImportPaketParams>)
class LoescheImportPaket implements UseCase<void, LoescheImportPaketParams> {
  final MandantenRepository _repository;

  LoescheImportPaket(this._repository);

  @override
  Future<Either<Failure, void>> call(LoescheImportPaketParams params) {
    return _repository.loescheImportPaket(params.nummer);
  }
}

class LoescheImportPaketParams {
  final int nummer;

  const LoescheImportPaketParams({required this.nummer});
}
