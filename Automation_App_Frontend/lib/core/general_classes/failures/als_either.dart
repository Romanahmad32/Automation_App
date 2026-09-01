import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';

/// Führt [aktion] aus und übersetzt das Ergebnis in ein `Either`: Erfolg
/// landet als `Right`, jede Ausnahme als `Left` mit einem [Failure].
///
/// Ohne [uebersetzen] wird die Ausnahme mit [ausnahmeText] von ihrem
/// technischen Präfix befreit und als [ServerFailure] verpackt — der übliche
/// Fall bei einer HTTP-Datasource. Eine Repository-Umsetzung, die eine eigene
/// Ausnahme abfängt (z. B. um deren Klartext unverändert weiterzugeben) oder
/// [LocalFailure] statt [ServerFailure] braucht, übergibt [uebersetzen].
///
/// Erspart den immer gleichen `try { return Right(await …) } catch (e) {
/// return Left(…) }`-Block in jeder Repository-Methode.
Future<Either<Failure, T>> alsEither<T>(
  Future<T> Function() aktion, {
  Failure Function(Object fehler)? uebersetzen,
}) async {
  try {
    return Right(await aktion());
  } catch (fehler) {
    final uebersetzt =
        uebersetzen ?? (Object f) => ServerFailure(message: ausnahmeText(f));
    return Left(uebersetzt(fehler));
  }
}
