import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Ablage eines fertigen Dokuments in der Akte (§6.1). Liefert den Zielpfad —
/// oder die Rückfrage, wenn dort schon eine gleichnamige Datei liegt.
@Injectable(as: UseCase<AblageErgebnis, LegeDokumentAbParams>)
class LegeDokumentAb implements UseCase<AblageErgebnis, LegeDokumentAbParams> {
  final MandantenRepository _repository;

  LegeDokumentAb(this._repository);

  @override
  Future<Either<Failure, AblageErgebnis>> call(LegeDokumentAbParams params) {
    return _repository.legeDokumentAb(params);
  }
}
