import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/data/datasources/form_template_datasource.dart';
import 'package:automation_app/features/form_template_setup/data/datasources/word_template_datasource.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: FormTemplateRepository)
class FormTemplateRepositoryImpl implements FormTemplateRepository {
  final FormTemplateDatasource _datasource;
  final WordTemplateDatasource _remoteWordTemplateDatasource;

  FormTemplateRepositoryImpl(
    this._datasource,
    this._remoteWordTemplateDatasource,
  );

  @override
  Future<Either<Failure, void>> createFormTemplate(
    CreateFormTemplateRequest template,
  ) => alsEither(
    () => _datasource.createFormTemplate(template),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, void>> deleteFormTemplate(int id) => alsEither(
    () => _datasource.deleteFormTemplate(id),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, FormTemplate>> getFormTemplateByName(String name) =>
      alsEither(
        () => _datasource.loadFormTemplateByName(name),
        uebersetzen: _localFailure,
      );

  @override
  Future<Either<Failure, List<FormTemplate>>> getFormTemplates() => alsEither(
    () => _datasource.loadFormTemplates(),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, FormTemplate>> updateFormTemplate(
    FormTemplate template,
  ) => alsEither(
    () => _datasource.updateFormTemplate(template),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, List<String>>> getTemplatePlaceholders(
    String wordFilePath,
  ) => alsEither(
    () => _remoteWordTemplateDatasource.getTemplatePlaceholders(wordFilePath),
    uebersetzen: (fehler) => ServerFailure(message: fehler.toString()),
  );

  /// Das volle `toString()` der Ausnahme, ungekürzt — anders als
  /// `ausnahmeText` bleibt das technische Präfix (z. B.
  /// `FormTemplateException: `) hier bewusst erhalten (bestehendes Verhalten).
  Failure _localFailure(Object fehler) =>
      LocalFailure(message: fehler.toString());
}
