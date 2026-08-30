import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/data/datasources/akten_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_datei_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/mandanten_import_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/mandant_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/ordner_status_datasource.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: MandantenRepository)
class MandantenRepositoryImpl implements MandantenRepository {
  final MandantDatasource _datasource;
  final FilesystemAktenDatasource _aktenDatasource;
  final OrdnerStatusDatasource _ordnerStatusDatasource;
  final ImportDateiDatasource _importDateiDatasource;
  final MandantenImportDatasource _importDatasource;
  final KanzleiSettingsRepository _settingsRepository;

  MandantenRepositoryImpl(
    this._datasource,
    this._aktenDatasource,
    this._ordnerStatusDatasource,
    this._importDateiDatasource,
    this._importDatasource,
    this._settingsRepository,
  );

  @override
  Future<Either<Failure, MandantenImportDatei>> liesImportDatei(
    String pfad,
  ) async {
    try {
      return Right(await _importDateiDatasource.lies(pfad));
    } on MandantException catch (e) {
      return Left(LocalFailure(message: e.message));
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, ImportBericht>> importiereMandanten({
    required MandantenImportDatei datei,
    required bool uebernehmen,
  }) async {
    try {
      return Right(
        await _importDatasource.importiere(
          datei: datei,
          uebernehmen: uebernehmen,
        ),
      );
    } on MandantException catch (e) {
      return Left(LocalFailure(message: e.message));
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, List<Mandant>>> getMandanten() async {
    try {
      return Right(await _datasource.loadMandanten());
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, MandantenSeite>> getMandantenSeite({
    String suche = '',
    int ueberspringen = 0,
    int anzahl = 0,
  }) async {
    try {
      return Right(
        await _datasource.ladeSeite(
          suche: suche,
          ueberspringen: ueberspringen,
          anzahl: anzahl,
        ),
      );
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAktenOrdnernamen() async {
    try {
      return Right(await _datasource.ladeAktenOrdnernamen());
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, Mandant>> createMandant(
    CreateMandantRequest request,
  ) async {
    try {
      return Right(await _datasource.createMandant(request));
    } on MandantException catch (e) {
      return Left(LocalFailure(message: e.message));
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, Mandant>> updateMandant(Mandant mandant) async {
    try {
      return Right(await _datasource.updateMandant(mandant));
    } on MandantException catch (e) {
      return Left(LocalFailure(message: e.message));
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMandant(int id) async {
    try {
      await _datasource.deleteMandant(id);
      return Right(null);
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, List<Akte>>> getAkten() async {
    try {
      final stammordner = await _ladeStammordner();
      return Right(await _aktenDatasource.scanAkten(stammordner));
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, List<Fall>>> getFaelle(String aktenPfad) async {
    try {
      return Right(await _aktenDatasource.scanFaelle(aktenPfad));
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, List<OrdnerStatus>>> getOrdnerStatus() async {
    try {
      return Right(await _ordnerStatusDatasource.ladeOrdnerStatus());
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, List<OrdnerStatus>>> setzeOrdnerStatus({
    required List<String> ordnernamen,
    required OrdnerStatusArt? art,
  }) async {
    try {
      return Right(
        await _ordnerStatusDatasource.setzeOrdnerStatus(
          ordnernamen: ordnernamen,
          art: art,
        ),
      );
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, Mandant>> verknuepfeOrdner({
    required int mandantId,
    required String ordnername,
  }) async {
    try {
      final aktualisiert = await _verknuepfe(mandantId, ordnername);
      return Right(aktualisiert);
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, AblageErgebnis>> legeDokumentAb(
    LegeDokumentAbParams params,
  ) async {
    try {
      final stammordner = await _ladeStammordner();
      final ergebnis = await _aktenDatasource.legeDokumentAb(
        stammordner: stammordner,
        ordnername: params.aktenOrdnername,
        unterordnerName: params.unterordnerName,
        quelldateiPfade: params.quelldateiPfade,
        strategie: params.strategie,
      );
      // Register und Dateisystem in Einklang halten: den (ggf. neu angelegten)
      // Akten-Ordner dem Mandanten zuordnen. Bei einer offenen Rückfrage liegt
      // noch nichts in der Akte — dann auch nichts zu verknüpfen.
      if (!ergebnis.konflikt) {
        await _verknuepfe(params.mandantId, params.aktenOrdnername);
      }
      return Right(ergebnis);
    } catch (e) {
      return Left(LocalFailure(message: ausnahmeText(e)));
    }
  }

  /// Fügt [ordnername] zu den Akten des Mandanten hinzu (idempotent) und
  /// speichert. Gibt den aktualisierten Mandanten zurück.
  Future<Mandant> _verknuepfe(int mandantId, String ordnername) async {
    final mandanten = await _datasource.loadMandanten();
    final mandant = mandanten.firstWhere(
      (m) => m.id == mandantId,
      orElse: () =>
          throw StateError('Mandant mit ID $mandantId nicht gefunden'),
    );
    // Ohne Rücksicht auf die Schreibweise: der Ordnername kommt aus dem
    // Dateisystem, und „VUnfallursache Mark" zweimal verschieden geschrieben
    // stünde sonst zweimal am Mandanten.
    if (OrdnernamenMenge(mandant.aktenOrdnernamen).enthaelt(ordnername)) {
      return mandant;
    }
    final aktualisiert = mandant.copyWith(
      aktenOrdnernamen: [...mandant.aktenOrdnernamen, ordnername],
    );
    return _datasource.updateMandant(aktualisiert);
  }

  Future<String> _ladeStammordner() async {
    final result = await _settingsRepository.getSettings();
    return switch (result) {
      Right(value: final settings) => settings.aktenStammordner,
      Left() => '',
    };
  }
}
