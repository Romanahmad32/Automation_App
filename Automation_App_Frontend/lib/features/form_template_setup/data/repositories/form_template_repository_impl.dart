import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/data/datasources/api_form_template_datasource.dart';
import 'package:automation_app/features/form_template_setup/data/datasources/remote_word_template_datasource.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: FormTemplateRepository)
class FormTemplateRepositoryImpl implements FormTemplateRepository {
  final FormTemplateDatasource _datasource;
  final RemoteWordTemplateDatasource _remoteWordTemplateDatasource;

  FormTemplateRepositoryImpl(
    this._datasource,
    this._remoteWordTemplateDatasource,
  );

  @override
  Future<Either<Failure, void>> createFormTemplate(
    CreateFormTemplateRequest template,
  ) async {
    try {
      await _datasource.createFormTemplate(template);
      return Right(null);
    } catch (e) {
      return Left(LocalFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFormTemplate(int id) async {
    try {
      await _datasource.deleteFormTemplate(id);
      return Right(null);
    } catch (e) {
      return Left(LocalFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FormTemplate>> getFormTemplateByName(
    String name,
  ) async {
    try {
      final template = await _datasource.loadFormTemplateByName(name);
      return Right(template);
    } catch (e) {
      return Left(LocalFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FormTemplate>>> getFormTemplates() async {
    try {
      final templates = await _datasource.loadFormTemplates();
      return Right(templates);
    } catch (e) {
      return Left(LocalFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FormTemplate>> updateFormTemplate(
    FormTemplate template,
  ) async {
    try {
      final updatedTemplate = await _datasource.updateFormTemplate(template);
      return Right(updatedTemplate);
    } catch (e) {
      return Left(LocalFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTemplatePlaceholders(
    String wordFilePath,
  ) async {
    try {
      final placeholders = await _remoteWordTemplateDatasource
          .getTemplatePlaceholders(wordFilePath);
      return Right(placeholders);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
