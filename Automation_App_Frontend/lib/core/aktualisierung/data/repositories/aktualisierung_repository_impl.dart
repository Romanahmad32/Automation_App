import 'package:automation_app/core/aktualisierung/data/datasources/aktualisierung_datasource.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/repositories/aktualisierung_repository.dart';
import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Übersetzt die rohe [AktualisierungDatasource] in `Either<Failure, T>`.
///
/// Eine Ablehnung des Dienstes (409) trägt ihren deutschen Satz in `detail`
/// (ProblemDetails) — der landet unverändert in der Rückmeldung. Antwortet
/// der Dienst gar nicht, sagt [dienstOhneAntwort], welcher Schritt liegen
/// blieb und warum.
@Injectable(as: AktualisierungRepository)
class AktualisierungRepositoryImpl implements AktualisierungRepository {
  final AktualisierungDatasource _datasource;

  AktualisierungRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, AktualisierungsStand>> stand() => _uebersetzt(
    _datasource.stand,
    'Der Stand der Aktualisierung ließ sich nicht abfragen',
  );

  @override
  Future<Either<Failure, AktualisierungsStand>> pruefen() => _uebersetzt(
    _datasource.pruefen,
    'Es ließ sich nicht nachsehen, ob eine neue Version vorliegt',
  );

  @override
  Future<Either<Failure, AktualisierungsStand>> herunterladen() => _uebersetzt(
    _datasource.herunterladen,
    'Das Herunterladen ließ sich nicht starten',
  );

  @override
  Future<Either<Failure, AktualisierungsStand>> abbrechen() => _uebersetzt(
    _datasource.abbrechen,
    'Das Herunterladen ließ sich nicht abbrechen',
  );

  @override
  Future<Either<Failure, AktualisierungsStand>> installieren() => _uebersetzt(
    _datasource.installieren,
    'Die Installation ließ sich nicht starten',
  );

  @override
  Future<Either<Failure, void>> ergebnisQuittieren() => _uebersetzt(
    _datasource.ergebnisQuittieren,
    'Das Ergebnis der Aktualisierung ließ sich nicht bestätigen',
  );

  Future<Either<Failure, T>> _uebersetzt<T>(
    Future<T> Function() aufruf,
    String was,
  ) => alsEither(
    aufruf,
    uebersetzen: (fehler) => ServerFailure(
      message: fehler is DioException
          ? backendFehlertext(fehler) ?? dienstOhneAntwort(fehler, was)
          : ausnahmeText(fehler),
    ),
  );
}
