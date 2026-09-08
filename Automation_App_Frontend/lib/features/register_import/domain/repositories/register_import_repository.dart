import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';

/// Der Weg der Registerhistorie in die App (§6.2): eine Datei von der Platte
/// lesen und sie vom Dienst prüfen oder schreiben lassen.
abstract class RegisterImportRepository {
  /// Liest die vom Anwalt gewählte Importdatei. Deutet sie nicht — was sie
  /// bewirkt, sagt erst der Dienst.
  Future<Either<Failure, RegisterImportDatei>> liesRegisterImportDatei(
    String pfad,
  );

  /// Prüft die Datei oder übernimmt sie. Beides ist derselbe Aufruf mit
  /// derselben Antwort; ohne [uebernehmen] wird nichts geschrieben.
  Future<Either<Failure, RegisterImportBericht>> importiereRegister({
    required RegisterImportDatei datei,
    required bool uebernehmen,
  });
}
