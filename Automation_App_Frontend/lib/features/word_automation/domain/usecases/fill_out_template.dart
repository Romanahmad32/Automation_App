import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<GeneratedDocument, FillOutTemplateParams>)
class FillOutTemplate
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  final WordAutomationRepository repository;

  FillOutTemplate({required this.repository});

  @override
  Future<Either<Failure, GeneratedDocument>> call(
      FillOutTemplateParams params,) async {
    return repository.fillOutTemplate(
      params.path,
      params.data,
      damageListing: params.damageListing,
      vorsteuerabzugsberechtigt: params.vorsteuerabzugsberechtigt,
      outputFileName: params.outputFileName,
    );
  }
}

class FillOutTemplateParams {
  final String path;
  final Map<String, String> data;
  final DamageListing? damageListing;
  final bool? vorsteuerabzugsberechtigt;

  /// Gewünschter Dateiname des Ergebnisses (ohne Pfad, mit/ohne .docx). Leer →
  /// das Backend bildet einen Fallback-Namen.
  final String? outputFileName;

  const FillOutTemplateParams({
    required this.path,
    required this.data,
    this.damageListing,
    this.vorsteuerabzugsberechtigt,
    this.outputFileName,
  });
}
