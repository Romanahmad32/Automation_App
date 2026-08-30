import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Setzt oder nimmt den Vermerk „ohne Mandantenbezug" zurück — für einen Ordner
/// oder für den ganzen gerade gefilterten Stapel.
@Injectable(as: UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams>)
class SetzeOrdnerStatus
    implements UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams> {
  final MandantenRepository _repository;

  SetzeOrdnerStatus(this._repository);

  @override
  Future<Either<Failure, List<OrdnerStatus>>> call(
    SetzeOrdnerStatusParams params,
  ) {
    return _repository.setzeOrdnerStatus(
      ordnernamen: params.ordnernamen,
      art: params.art,
    );
  }
}

class SetzeOrdnerStatusParams {
  final List<String> ordnernamen;

  /// `null` nimmt den Vermerk zurück: der Ordner steht wieder im Stapel.
  final OrdnerStatusArt? art;

  const SetzeOrdnerStatusParams({required this.ordnernamen, required this.art});
}
