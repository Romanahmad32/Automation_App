import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

/// Löscht den Arbeitsordner eines Vorgangs, sobald das Schreiben in der Akte
/// liegt. Ab da ist die Kopie in der Akte die gültige Fassung — Zwischenstände
/// früherer Anläufe sammeln sich nicht an (§4.6).
@Injectable(
  as: UseCase<ArbeitsordnerAufraeumung, ArbeitsordnerAufraeumenParams>,
)
class ArbeitsordnerAufraeumen
    implements
        UseCase<ArbeitsordnerAufraeumung, ArbeitsordnerAufraeumenParams> {
  final WordAutomationRepository repository;

  ArbeitsordnerAufraeumen({required this.repository});

  @override
  Future<Either<Failure, ArbeitsordnerAufraeumung>> call(
    ArbeitsordnerAufraeumenParams params,
  ) async {
    return repository.arbeitsordnerAufraeumen(params.vorgangSchluessel);
  }
}

class ArbeitsordnerAufraeumenParams {
  /// Referenz des Vorgangs — derselbe Schlüssel, unter dem erzeugt wurde.
  /// Leer = der Ordner der freien Erfassung ohne Vorgangsbezug.
  final String vorgangSchluessel;

  const ArbeitsordnerAufraeumenParams(this.vorgangSchluessel);
}
