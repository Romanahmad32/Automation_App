import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/data/datasources/arbeitspaket_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/arbeitspaket_datei_datasource.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/arbeitspaket_repository.dart';
import 'package:automation_app/features/mandanten/domain/repositories/kein_offener_ordner.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: ArbeitspaketRepository)
class ArbeitspaketRepositoryImpl implements ArbeitspaketRepository {
  final ArbeitspaketDatasource _datasource;
  final ArbeitspaketDateiDatasource _dateiDatasource;

  ArbeitspaketRepositoryImpl(this._datasource, this._dateiDatasource);

  @override
  Future<Either<Failure, List<Arbeitspaket>>> ladePakete() =>
      alsEither(() => _datasource.ladePakete(), uebersetzen: _localFailure);

  @override
  Future<Either<Failure, Arbeitspaket>> holePaket({
    required List<String> ordnernamen,
    required int anzahl,
  }) => alsEither(
    () => _datasource.holePaket(ordnernamen: ordnernamen, anzahl: anzahl),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, void>> schreibeDatei({
    required String pfad,
    required String inhalt,
  }) => alsEither(
    () => _dateiDatasource.schreibe(pfad, inhalt),
    uebersetzen: _localFailure,
  );

  /// Wie im Mandanten-Repository: die Ausnahmen kommen aus Dateisystem und
  /// Dienst und tragen ihren Klartext schon mit sich.
  ///
  /// Die eine Ausnahme davon behält ihren eigenen Typ: „kein Ordner mehr
  /// offen" ist der Abschluss des Vorgangs, kein Fehler — und die Oberfläche
  /// darf das nicht an einem Meldungstext erkennen müssen.
  Failure _localFailure(Object fehler) => fehler is KeinOffenerOrdnerException
      ? KeinOffenerOrdnerFailure(message: fehler.message)
      : LocalFailure(message: ausnahmeText(fehler));
}
