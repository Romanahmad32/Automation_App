import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';

abstract class FormTemplateRepository {
  Future<Either<Failure, FormTemplate>> getFormTemplateByName(String name);

  Future<Either<Failure, List<FormTemplate>>> getFormTemplates();

  Future<Either<Failure, void>> createFormTemplate(
    CreateFormTemplateRequest template,
  );

  Future<Either<Failure, FormTemplate>> updateFormTemplate(
    FormTemplate template,
  );

  Future<Either<Failure, void>> deleteFormTemplate(int id);

  /// Liest die {{Platzhalter}} aus, die in der verknüpften Word-Datei erkannt werden.
  Future<Either<Failure, List<String>>> getTemplatePlaceholders(
    String wordFilePath,
  );
}
