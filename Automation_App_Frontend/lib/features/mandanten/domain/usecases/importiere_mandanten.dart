import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Prüft eine Importdatei oder übernimmt sie. Beides ist derselbe Aufruf mit
/// derselben Antwort — die Vorschau kann deshalb nicht von dem abweichen, was
/// die Übernahme tut.
@Injectable(as: UseCase<ImportBericht, ImportiereMandantenParams>)
class ImportiereMandanten
    implements UseCase<ImportBericht, ImportiereMandantenParams> {
  final MandantenRepository _repository;

  ImportiereMandanten(this._repository);

  @override
  Future<Either<Failure, ImportBericht>> call(
    ImportiereMandantenParams params,
  ) {
    return _repository.importiereMandanten(
      datei: params.datei,
      uebernehmen: params.uebernehmen,
    );
  }
}

class ImportiereMandantenParams {
  final MandantenImportDatei datei;

  /// false prüft nur; true schreibt ins Register.
  final bool uebernehmen;

  const ImportiereMandantenParams({
    required this.datei,
    required this.uebernehmen,
  });
}
