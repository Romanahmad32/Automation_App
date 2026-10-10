import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/data/datasources/vollmacht_datasource.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/repositories/vollmacht_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Übersetzt die rohe [VollmachtDatasource] in `Either<Failure, T>` mit
/// anzeigbaren, deutschen Texten.
@Injectable(as: VollmachtRepository)
class VollmachtRepositoryImpl implements VollmachtRepository {
  final VollmachtDatasource _datasource;

  VollmachtRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, VollmachtVorlagenStand>> ladeVorlagen() => _versuche(
    _datasource.ladeVorlagen,
    'Der Stand der Vollmacht-Vorlagen konnte nicht geladen werden',
  );

  @override
  Future<Either<Failure, Mandant?>> ladeMandant(int id) => _versuche(
    () => _datasource.ladeMandant(id),
    'Der Mandant zum Vorgang konnte nicht geladen werden',
  );

  @override
  Future<Either<Failure, VollmachtErgebnis>> drucke(VollmachtAuftrag auftrag) =>
      _versuche(
        () => _datasource.drucke(auftrag),
        'Die Vollmacht konnte nicht gedruckt werden',
      );

  @override
  Future<Either<Failure, VollmachtErgebnis>> fuelleAus(
    VollmachtAuftrag auftrag,
  ) => _versuche(
    () => _datasource.fuelleAus(auftrag),
    'Die Vollmacht konnte nicht ausgefüllt werden',
  );

  Future<Either<Failure, T>> _versuche<T>(
    Future<T> Function() abruf,
    String was,
  ) async {
    try {
      return Right(await abruf());
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: backendFehlertext(e) ?? dienstOhneAntwort(e, was),
        ),
      );
    } catch (e) {
      return Left(LocalFailure(message: '$was: ${ausnahmeText(e)}'));
    }
  }
}
