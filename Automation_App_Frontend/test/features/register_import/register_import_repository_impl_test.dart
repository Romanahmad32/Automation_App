import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_datei_datasource.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/register_import/data/datasources/register_import_datasource.dart';
import 'package:automation_app/features/register_import/data/repositories/register_import_repository_impl.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wirft [MandantException], statt eine Datei zu liefern — das Lesen selbst
/// kommt aus `mandanten` (§5.1/§6.1) und wird dort schon geprüft; hier zählt
/// nur, dass der Fehlertext unverändert beim Anwalt ankommt.
class FehlschlagendeImportDateiDatasource implements ImportDateiDatasource {
  final String nachricht;

  FehlschlagendeImportDateiDatasource(this.nachricht);

  @override
  Future<MandantenImportDatei> lies(String pfad) =>
      throw MandantException(nachricht);

  @override
  Future<Map<String, dynamic>> liesJson(String pfad) =>
      throw MandantException(nachricht);
}

/// In diesem Test nie aufgerufen: Die Datei scheitert schon beim Lesen, bevor
/// der Dienst überhaupt gefragt wird.
class UngenutzteRegisterImportDatasource implements RegisterImportDatasource {
  @override
  Future<RegisterImportBericht> importiere({
    required RegisterImportDatei datei,
    required bool uebernehmen,
  }) => throw UnimplementedError('wird in diesem Test nicht gebraucht');
}

void main() {
  test(
    'eine MandantException beim Lesen landet als Failure mit demselben Text',
    () async {
      const nachricht = 'Die Datei „x.json" gibt es nicht.';
      final repository = RegisterImportRepositoryImpl(
        FehlschlagendeImportDateiDatasource(nachricht),
        UngenutzteRegisterImportDatasource(),
      );

      final ergebnis = await repository.liesRegisterImportDatei('x.json');

      expect(ergebnis, isA<Left<Failure, RegisterImportDatei>>());
      final failure = (ergebnis as Left<Failure, RegisterImportDatei>).value;
      expect(failure, isA<LocalFailure>());
      expect(failure.message, nachricht);
    },
  );
}
