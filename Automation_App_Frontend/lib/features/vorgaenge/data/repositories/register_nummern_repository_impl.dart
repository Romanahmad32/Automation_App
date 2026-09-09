import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vorgaenge/data/datasources/register_nummern_datasource.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_nummern_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_nummern_repository.dart';
import 'package:injectable/injectable.dart';

/// Übersetzt einen fehlgeschlagenen Abruf des Nummernstands in ein `Either` —
/// die `RegisterException` der Datasource verliert dabei nur ihr technisches
/// Präfix (`alsEither`s Vorgabe reicht, es gibt hier nichts Eigenes zu
/// übersetzen).
@Injectable(as: RegisterNummernRepository)
class RegisterNummernRepositoryImpl implements RegisterNummernRepository {
  final RegisterNummernDatasource _datasource;

  RegisterNummernRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, RegisterNummernStand>> ladeNummernstand({
    int? jahrgang,
  }) => alsEither(() => _datasource.ladeNummernstand(jahrgang: jahrgang));
}
