import 'dart:typed_data';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';

abstract class WordAutomationRepository {
  Future<Either<Failure, GeneratedDocument>> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
    String? vorgangSchluessel,
  });

  /// Löscht den Arbeitsordner des Vorgangs, nachdem das Schreiben in der Akte
  /// liegt (§4.6).
  Future<Either<Failure, ArbeitsordnerAufraeumung>> arbeitsordnerAufraeumen(
    String vorgangSchluessel,
  );

  Future<Either<Failure, Uint8List>> convertDocxToPdf(String docxFilePath);

  /// Vorlagenordner des Anwenders samt Inhalt.
  Future<Either<Failure, VorlagenUebersicht>> getVorlagenUebersicht();

  Future<Either<Failure, RvgCalculation>> calculateRvgFees(
    double gegenstandswert,
    double gebuehrensatz,
    bool applyVat, {
    double? geschaeftsgebuehrOverride,
    double? auslagenpauschaleOverride,
  });
}
