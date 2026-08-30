import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Lädt die Fälle einer einzelnen Akte nach — der Erst-Scan liest sie nicht
/// mit (siehe `FilesystemAktenDatasource.scanAkten`).
@Injectable(as: UseCase<List<Fall>, GetFaelleParams>)
class GetFaelle implements UseCase<List<Fall>, GetFaelleParams> {
  final MandantenRepository _repository;

  GetFaelle(this._repository);

  @override
  Future<Either<Failure, List<Fall>>> call(GetFaelleParams params) {
    return _repository.getFaelle(params.aktenPfad);
  }
}

class GetFaelleParams {
  /// Vollständiger Pfad des Akten-Ordners (`Akte.pfad`).
  final String aktenPfad;

  const GetFaelleParams(this.aktenPfad);
}
