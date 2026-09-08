import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:automation_app/features/register_import/domain/repositories/register_import_repository.dart';
import 'package:injectable/injectable.dart';

/// Liest die gewählte Registerdatei ein — ohne sie zu deuten. Was sie bewirkt,
/// sagt erst der Dienst (`ImportiereRegister`).
@Injectable(as: UseCase<RegisterImportDatei, LiesRegisterImportDateiParams>)
class LiesRegisterImportDatei
    implements UseCase<RegisterImportDatei, LiesRegisterImportDateiParams> {
  final RegisterImportRepository _repository;

  LiesRegisterImportDatei(this._repository);

  @override
  Future<Either<Failure, RegisterImportDatei>> call(
    LiesRegisterImportDateiParams params,
  ) {
    return _repository.liesRegisterImportDatei(params.pfad);
  }
}

class LiesRegisterImportDateiParams {
  final String pfad;

  const LiesRegisterImportDateiParams({required this.pfad});
}
