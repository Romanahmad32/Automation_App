import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/repositories/arbeitspaket_repository.dart';
import 'package:injectable/injectable.dart';

/// Legt die fertige Paketdatei auf der Platte ab — das, was der Erzeuger als
/// Eingabe bekommt.
@Injectable(as: UseCase<void, SchreibeArbeitspaketDateiParams>)
class SchreibeArbeitspaketDatei
    implements UseCase<void, SchreibeArbeitspaketDateiParams> {
  final ArbeitspaketRepository _repository;

  SchreibeArbeitspaketDatei(this._repository);

  @override
  Future<Either<Failure, void>> call(SchreibeArbeitspaketDateiParams params) {
    return _repository.schreibeDatei(pfad: params.pfad, inhalt: params.inhalt);
  }
}

class SchreibeArbeitspaketDateiParams {
  /// Vollständiger Zielpfad einschließlich Dateiname.
  final String pfad;

  final String inhalt;

  const SchreibeArbeitspaketDateiParams({
    required this.pfad,
    required this.inhalt,
  });
}
