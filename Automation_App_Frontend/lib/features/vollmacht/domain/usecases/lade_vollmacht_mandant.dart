import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:injectable/injectable.dart';

/// Holt den einen Mandanten, dessen Stammdaten die Vollmacht vorbelegen
/// (§4.11) — gezielt über die ID, nicht über das ganze Register.
@injectable
class LadeVollmachtMandant implements UseCase<Mandant?, int> {
  final VollmachtRepository _repository;

  LadeVollmachtMandant(this._repository);

  @override
  Future<Either<Failure, Mandant?>> call(int mandantId) =>
      _repository.ladeMandant(mandantId);
}
