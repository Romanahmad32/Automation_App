import 'dart:io';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/backup/data/datasources/backup_datasource.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Übersetzt den rohen `BackupDatasource`-Zugriff in `Either<Failure, T>` und
/// erledigt den Dateizugriff für Export/Import — beides lag zuvor im
/// `BackupCubit`, dem einzigen Schichtbruch im Bestand (Dio und dart:io in
/// der Präsentation).
@Injectable(as: BackupRepository)
class BackupRepositoryImpl implements BackupRepository {
  final BackupDatasource _datasource;

  BackupRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, String>> exportiereNach(String zielPfad) async {
    try {
      final bytes = await _datasource.exportDatenbank();
      await File(zielPfad).writeAsBytes(bytes, flush: true);
      return Right('Sicherung gespeichert unter:\n$zielPfad');
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: backendFehlertext(e) ?? 'Export fehlgeschlagen.',
        ),
      );
    } catch (e) {
      return Left(
        LocalFailure(message: 'Export fehlgeschlagen: ${ausnahmeText(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> importiere(String dateipfad) async {
    try {
      return Right(await _datasource.importDatenbank(dateipfad));
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: backendFehlertext(e) ?? 'Import fehlgeschlagen.',
        ),
      );
    } catch (e) {
      return Left(
        LocalFailure(message: 'Import fehlgeschlagen: ${ausnahmeText(e)}'),
      );
    }
  }

  @override
  Future<UebergabeStand> uebergabeStand() => _datasource.uebergabeStand();

  @override
  Future<String> uebernehmeStand() => _datasource.uebernehmeStand();

  @override
  Future<void> quittiereSicherungsfehler() =>
      _datasource.quittiereSicherungsfehler();
}
