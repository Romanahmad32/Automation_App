import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Ablage eines fertigen Dokuments in der Akte (§3.6). Gibt den Zielpfad der
/// abgelegten Kopie zurück.
@Injectable(as: UseCase<String, LegeDokumentAbParams>)
class LegeDokumentAb implements UseCase<String, LegeDokumentAbParams> {
  final MandantenRepository _repository;

  LegeDokumentAb(this._repository);

  @override
  Future<Either<Failure, String>> call(LegeDokumentAbParams params) {
    return _repository.legeDokumentAb(params);
  }
}
