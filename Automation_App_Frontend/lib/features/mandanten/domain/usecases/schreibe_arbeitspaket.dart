import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Schreibt das gebaute Arbeitspaket als JSON-Datei — die Eingabe für den
/// Agenten, der daraus die Importdatei erzeugt.
@Injectable(as: UseCase<void, SchreibeArbeitspaketParams>)
class SchreibeArbeitspaket
    implements UseCase<void, SchreibeArbeitspaketParams> {
  final MandantenRepository _repository;

  SchreibeArbeitspaket(this._repository);

  @override
  Future<Either<Failure, void>> call(SchreibeArbeitspaketParams params) {
    return _repository.schreibeArbeitspaket(
      paket: params.paket,
      pfad: params.pfad,
    );
  }
}

class SchreibeArbeitspaketParams {
  final Arbeitspaket paket;

  /// Vollständiger Zielpfad — den hat der Anwalt im Speichern-Dialog bestimmt
  /// (`Arbeitspaket.dateiname` ist der Vorschlag dafür).
  final String pfad;

  const SchreibeArbeitspaketParams({required this.paket, required this.pfad});
}
