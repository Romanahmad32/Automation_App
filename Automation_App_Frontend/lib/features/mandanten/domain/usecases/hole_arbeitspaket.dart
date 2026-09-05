import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/arbeitspaket_repository.dart';
import 'package:injectable/injectable.dart';

/// Holt das nächste Arbeitspaket und schreibt es in die Historie. Der Aufruf
/// verändert damit den Stand — anders als eine Abfrage darf er nicht auf
/// Verdacht wiederholt werden.
@Injectable(as: UseCase<Arbeitspaket, HoleArbeitspaketParams>)
class HoleArbeitspaket
    implements UseCase<Arbeitspaket, HoleArbeitspaketParams> {
  final ArbeitspaketRepository _repository;

  HoleArbeitspaket(this._repository);

  @override
  Future<Either<Failure, Arbeitspaket>> call(HoleArbeitspaketParams params) {
    return _repository.holePaket(
      ordnernamen: params.ordnernamen,
      anzahl: params.anzahl,
    );
  }
}

class HoleArbeitspaketParams {
  /// **Alle** gescannten Ordnernamen. Welche davon noch offen sind, weiß der
  /// Dienst: er zieht Zugeordnete und Vermerkte ab und sortiert stabil.
  final List<String> ordnernamen;

  /// Wie viele Ordner das Paket umfassen soll.
  final int anzahl;

  const HoleArbeitspaketParams({
    required this.ordnernamen,
    required this.anzahl,
  });
}
