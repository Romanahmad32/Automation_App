import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

/// Erzeugt die PDF-Fassung des fertigen Schreibens als Datei neben der
/// Word-Datei und liefert deren Pfad — die Vorlage für die Ablage in der Akte
/// (§6.1), wenn der Anwalt „PDF" oder „Word + PDF" gewählt hat.
@Injectable(as: UseCase<String, ErzeugePdfFassungParams>)
class ErzeugePdfFassung implements UseCase<String, ErzeugePdfFassungParams> {
  final WordAutomationRepository repository;

  ErzeugePdfFassung({required this.repository});

  @override
  Future<Either<Failure, String>> call(ErzeugePdfFassungParams params) {
    return repository.erzeugePdfFassung(params.docxFilePath);
  }
}

class ErzeugePdfFassungParams {
  final String docxFilePath;

  const ErzeugePdfFassungParams(this.docxFilePath);
}
