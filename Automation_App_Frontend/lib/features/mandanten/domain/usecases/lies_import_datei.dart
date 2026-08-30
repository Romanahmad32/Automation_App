import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Liest die vom Anwender gewählte Importdatei ein — ohne sie zu deuten. Was
/// sie bewirkt, sagt erst der Dienst (`ImportiereMandanten`).
@Injectable(as: UseCase<MandantenImportDatei, LiesImportDateiParams>)
class LiesImportDatei
    implements UseCase<MandantenImportDatei, LiesImportDateiParams> {
  final MandantenRepository _repository;

  LiesImportDatei(this._repository);

  @override
  Future<Either<Failure, MandantenImportDatei>> call(
    LiesImportDateiParams params,
  ) {
    return _repository.liesImportDatei(params.pfad);
  }
}

class LiesImportDateiParams {
  final String pfad;

  const LiesImportDateiParams({required this.pfad});
}
