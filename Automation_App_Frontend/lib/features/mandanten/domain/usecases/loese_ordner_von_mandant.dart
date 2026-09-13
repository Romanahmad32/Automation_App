import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Das Gegenstück zu `VerknuepfeOrdnerMitMandant`: nimmt einen Akten-Ordner
/// vom Mandanten. Der Ordner im Dateisystem bleibt, wie er ist (#132).
@Injectable(as: UseCase<Mandant, LoeseOrdnerParams>)
class LoeseOrdnerVonMandant implements UseCase<Mandant, LoeseOrdnerParams> {
  final MandantenRepository _repository;

  LoeseOrdnerVonMandant(this._repository);

  @override
  Future<Either<Failure, Mandant>> call(LoeseOrdnerParams params) {
    return _repository.loeseOrdner(
      mandantId: params.mandantId,
      ordnername: params.ordnername,
    );
  }
}

class LoeseOrdnerParams {
  final int mandantId;
  final String ordnername;

  const LoeseOrdnerParams({required this.mandantId, required this.ordnername});
}
