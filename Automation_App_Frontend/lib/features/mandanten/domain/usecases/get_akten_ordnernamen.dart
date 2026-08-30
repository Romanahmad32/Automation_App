import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Die Namen **aller** zugeordneten Akten-Ordner. Der Zuordnungsstapel teilt
/// damit den Scan in „gehört schon einem Mandanten" und „offen" — die geladene
/// Seite des Registers reicht dafür nicht, und dafür alle Mandanten zu holen
/// wäre genau der Abruf, den die seitenweise Liste vermeidet.
@Injectable(as: UseCase<List<String>, NoParams>)
class GetAktenOrdnernamen implements UseCase<List<String>, NoParams> {
  final MandantenRepository _repository;

  GetAktenOrdnernamen(this._repository);

  @override
  Future<Either<Failure, List<String>>> call(NoParams params) {
    return _repository.getAktenOrdnernamen();
  }
}
