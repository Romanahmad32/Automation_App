import 'dart:typed_data';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/data/datasources/word_automation_datasource.dart';
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: WordAutomationRepository)
class WordAutomationRepositoryImpl implements WordAutomationRepository {
  final WordAutomationDatasource datasource;

  WordAutomationRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, VorlagenUebersicht>> getVorlagenUebersicht() async {
    try {
      return Right(await datasource.getVorlagenUebersicht());
    } catch (e) {
      return Left(ServerFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, GeneratedDocument>> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
    String? vorgangSchluessel,
  }) async {
    try {
      final result = await datasource.fillOutTemplate(
        path,
        values,
        damageListing: damageListing,
        vorsteuerabzugsberechtigt: vorsteuerabzugsberechtigt,
        outputFileName: outputFileName,
        vorgangSchluessel: vorgangSchluessel,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, ArbeitsordnerAufraeumung>> arbeitsordnerAufraeumen(
    String vorgangSchluessel,
  ) async {
    try {
      return Right(await datasource.arbeitsordnerAufraeumen(vorgangSchluessel));
    } catch (e) {
      return Left(ServerFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> convertDocxToPdf(
    String docxFilePath,
  ) async {
    try {
      final result = await datasource.convertDocxToPdf(docxFilePath);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: ausnahmeText(e)));
    }
  }

  @override
  Future<Either<Failure, RvgCalculation>> calculateRvgFees(
    double gegenstandswert,
    double gebuehrensatz,
    bool applyVat, {
    double? geschaeftsgebuehrOverride,
    double? auslagenpauschaleOverride,
  }) async {
    try {
      final result = await datasource.calculateRvgFees(
        gegenstandswert,
        gebuehrensatz,
        applyVat,
        geschaeftsgebuehrOverride: geschaeftsgebuehrOverride,
        auslagenpauschaleOverride: auslagenpauschaleOverride,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: ausnahmeText(e)));
    }
  }
}
