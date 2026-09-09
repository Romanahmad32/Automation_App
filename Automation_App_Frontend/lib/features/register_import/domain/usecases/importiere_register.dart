import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:automation_app/features/register_import/domain/repositories/register_import_repository.dart';
import 'package:injectable/injectable.dart';

/// Prüft einen Jahrgang der Registerhistorie oder übernimmt ihn. Beides ist
/// derselbe Aufruf mit derselben Antwort — die Vorschau kann deshalb nicht von
/// dem abweichen, was die Übernahme tut.
@Injectable(as: UseCase<RegisterImportBericht, ImportiereRegisterParams>)
class ImportiereRegister
    implements UseCase<RegisterImportBericht, ImportiereRegisterParams> {
  final RegisterImportRepository _repository;

  ImportiereRegister(this._repository);

  @override
  Future<Either<Failure, RegisterImportBericht>> call(
    ImportiereRegisterParams params,
  ) {
    return _repository.importiereRegister(
      datei: params.datei,
      uebernehmen: params.uebernehmen,
    );
  }
}

class ImportiereRegisterParams {
  final RegisterImportDatei datei;

  /// false prüft nur; true schreibt in die Registerhistorie.
  final bool uebernehmen;

  const ImportiereRegisterParams({
    required this.datei,
    required this.uebernehmen,
  });
}
