import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Ein Ausschnitt des Registers für die Mandantenliste — sie holt nicht alle
/// tausende Mandanten auf einmal, sondern lädt beim Weiterscrollen nach.
@Injectable(as: UseCase<MandantenSeite, MandantenSeiteParams>)
class GetMandantenSeite
    implements UseCase<MandantenSeite, MandantenSeiteParams> {
  final MandantenRepository _repository;

  GetMandantenSeite(this._repository);

  @override
  Future<Either<Failure, MandantenSeite>> call(MandantenSeiteParams params) {
    return _repository.getMandantenSeite(
      suche: params.suche,
      ueberspringen: params.ueberspringen,
      anzahl: params.anzahl,
    );
  }
}

class MandantenSeiteParams {
  /// Freitext über Name, Ort und Ordnernamen. Er gilt dem **ganzen** Bestand,
  /// nicht dem schon geladenen Teil.
  final String suche;

  /// Wie viele Treffer vor diesem Ausschnitt liegen.
  final int ueberspringen;

  /// Größe des Ausschnitts; 0 überlässt sie dem Dienst.
  final int anzahl;

  const MandantenSeiteParams({
    this.suche = '',
    this.ueberspringen = 0,
    this.anzahl = 0,
  });
}
