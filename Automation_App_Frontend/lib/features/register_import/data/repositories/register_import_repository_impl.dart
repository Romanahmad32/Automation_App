import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_datei_datasource.dart';
import 'package:automation_app/features/register_import/data/datasources/register_import_datasource.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:automation_app/features/register_import/domain/repositories/register_import_repository.dart';
import 'package:injectable/injectable.dart';

/// Übersetzt die beiden Herkünfte des Registerimports in Domain-Typen und
/// `Failure`s: die Datei auf der Platte und den Dienst.
///
/// Das Lesen der Datei kommt aus `mandanten` ([ImportDateiDatasource]) und
/// wird **nicht** kopiert: Es ist derselbe Griff auf dieselbe Art Datei, und
/// zwei Fassungen davon liefen beim ersten Sonderfall auseinander. Gedeutet
/// wird die Datei hier — `fromJson` gehört dem Feature, das ihr Format kennt.
@Injectable(as: RegisterImportRepository)
class RegisterImportRepositoryImpl implements RegisterImportRepository {
  final ImportDateiDatasource _dateiDatasource;
  final RegisterImportDatasource _importDatasource;

  RegisterImportRepositoryImpl(this._dateiDatasource, this._importDatasource);

  @override
  Future<Either<Failure, RegisterImportDatei>> liesRegisterImportDatei(
    String pfad,
  ) => alsEither(() async {
    return RegisterImportDatei.fromJson(await _dateiDatasource.liesJson(pfad));
  }, uebersetzen: _localFailure);

  @override
  Future<Either<Failure, RegisterImportBericht>> importiereRegister({
    required RegisterImportDatei datei,
    required bool uebernehmen,
  }) => alsEither(
    () => _importDatasource.importiere(datei: datei, uebernehmen: uebernehmen),
    uebersetzen: _localFailure,
  );

  /// Der Klartext des Dienstes bzw. der Datei bleibt stehen — er ist die
  /// Auskunft, die der Anwalt braucht, nicht der Ausnahmetyp darüber.
  Failure _localFailure(Object fehler) =>
      LocalFailure(message: ausnahmeText(fehler));
}
