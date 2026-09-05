import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/arbeitspaket_repository.dart';
import 'package:injectable/injectable.dart';

/// Die Paket-Historie, neuestes zuerst — daran sieht der Anwalt, dass Paket 3
/// fehlt, bevor er Paket 4 holt.
@Injectable(as: UseCase<List<Arbeitspaket>, NoParams>)
class GetArbeitspakete implements UseCase<List<Arbeitspaket>, NoParams> {
  final ArbeitspaketRepository _repository;

  GetArbeitspakete(this._repository);

  @override
  Future<Either<Failure, List<Arbeitspaket>>> call(NoParams params) {
    return _repository.ladePakete();
  }
}
