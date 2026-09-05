import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';

/// Die Arbeitspakete des Mandanten-Imports: Historie holen, das nächste Paket
/// anfordern, die fertige Paketdatei ablegen.
///
/// Bewusst **neben** `MandantenRepository` und nicht darin: das dortige
/// Register-Repository trägt schon sechs Abhängigkeiten, und die Pakete sind
/// ein eigener Vorgang mit eigener Buchführung. Ein Repository, das beides
/// führt, wächst genau so lange weiter, bis niemand mehr sagen kann, wofür es
/// zuständig ist.
abstract class ArbeitspaketRepository {
  /// Die bisher herausgegebenen Pakete, neuestes zuerst.
  Future<Either<Failure, List<Arbeitspaket>>> ladePakete();

  /// Gibt das nächste Paket heraus. [ordnernamen] sind **alle** gescannten
  /// Ordner — welche davon noch offen sind, entscheidet der Dienst.
  Future<Either<Failure, Arbeitspaket>> holePaket({
    required List<String> ordnernamen,
    required int anzahl,
  });

  /// Legt die fertige Paketdatei unter [pfad] ab.
  Future<Either<Failure, void>> schreibeDatei({
    required String pfad,
    required String inhalt,
  });
}
