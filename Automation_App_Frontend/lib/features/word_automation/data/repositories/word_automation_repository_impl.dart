import 'dart:io';
import 'dart:typed_data';

import 'package:automation_app/core/general_classes/failures/als_either.dart';
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
  Future<Either<Failure, VorlagenUebersicht>> getVorlagenUebersicht() =>
      alsEither(() => datasource.getVorlagenUebersicht());

  @override
  Future<Either<Failure, GeneratedDocument>> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
    String? vorgangSchluessel,
  }) => alsEither(
    () => datasource.fillOutTemplate(
      path,
      values,
      damageListing: damageListing,
      vorsteuerabzugsberechtigt: vorsteuerabzugsberechtigt,
      outputFileName: outputFileName,
      vorgangSchluessel: vorgangSchluessel,
    ),
  );

  @override
  Future<Either<Failure, ArbeitsordnerAufraeumung>> arbeitsordnerAufraeumen(
    String vorgangSchluessel,
  ) => alsEither(() => datasource.arbeitsordnerAufraeumen(vorgangSchluessel));

  @override
  Future<Either<Failure, Uint8List>> convertDocxToPdf(String docxFilePath) =>
      alsEither(() => datasource.convertDocxToPdf(docxFilePath));

  @override
  Future<Either<Failure, String>> erzeugePdfFassung(String docxFilePath) =>
      alsEither(() async {
        final bytes = await datasource.convertDocxToPdf(docxFilePath);
        final ziel = _pdfPfadNeben(docxFilePath);
        await File(ziel).writeAsBytes(bytes, flush: true);
        return ziel;
      });

  /// Derselbe Pfad mit `.pdf` statt der bisherigen Endung — gleicher Ordner,
  /// gleicher Name. So gehören Word- und PDF-Fassung in der Akte sichtbar
  /// zusammen.
  String _pdfPfadNeben(String docxFilePath) {
    final punkt = docxFilePath.lastIndexOf('.');
    final trenner = docxFilePath.lastIndexOf(RegExp(r'[\\/]'));
    // Ein Punkt im Ordnernamen ist keine Dateiendung.
    if (punkt <= trenner) return '$docxFilePath.pdf';
    return '${docxFilePath.substring(0, punkt)}.pdf';
  }

  @override
  Future<Either<Failure, RvgCalculation>> calculateRvgFees(
    double gegenstandswert,
    double gebuehrensatz,
    bool applyVat, {
    double? geschaeftsgebuehrOverride,
    double? auslagenpauschaleOverride,
  }) => alsEither(
    () => datasource.calculateRvgFees(
      gegenstandswert,
      gebuehrensatz,
      applyVat,
      geschaeftsgebuehrOverride: geschaeftsgebuehrOverride,
      auslagenpauschaleOverride: auslagenpauschaleOverride,
    ),
  );
}
