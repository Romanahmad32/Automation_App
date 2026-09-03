import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Formularvorlagen über das Backend (`api/FormTemplates`). Löst den früheren
/// lokalen JSON-Speicher (form_templates.json) ab; ID-Vergabe und Namens-
/// Eindeutigkeit macht jetzt das Backend.
abstract class FormTemplateDatasource {
  Future<List<FormTemplate>> loadFormTemplates();

  Future<FormTemplate> loadFormTemplateByName(String name);

  Future<void> createFormTemplate(CreateFormTemplateRequest templateRequest);

  Future<FormTemplate> updateFormTemplate(FormTemplate template);

  Future<void> deleteFormTemplate(int id);
}

@Injectable(as: FormTemplateDatasource)
class ApiFormTemplateDatasource implements FormTemplateDatasource {
  final Dio _dio;

  ApiFormTemplateDatasource(this._dio);

  @override
  Future<List<FormTemplate>> loadFormTemplates() async {
    final response = await _dio.get('/api/FormTemplates');
    final list = response.data as List;
    return list
        .map((item) => FormTemplate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FormTemplate> loadFormTemplateByName(String name) async {
    // Vorlagen sind wenige; eine Filterung auf der geladenen Liste genügt und
    // erspart einen eigenen Endpunkt mit Namens-Encoding.
    final templates = await loadFormTemplates();
    final treffer = templates.where((t) => t.templateName == name);
    if (treffer.isEmpty) {
      throw FormTemplateException('Vorlage mit dem Namen $name nicht gefunden');
    }
    return treffer.first;
  }

  @override
  Future<void> createFormTemplate(
    CreateFormTemplateRequest templateRequest,
  ) async {
    try {
      await _dio.post(
        '/api/FormTemplates',
        data: templateRequest.toJson(),
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<FormTemplate> updateFormTemplate(FormTemplate template) async {
    try {
      final response = await _dio.put(
        '/api/FormTemplates/${template.id}',
        data: template.toJson(),
        options: Options(contentType: Headers.jsonContentType),
      );
      return FormTemplate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> deleteFormTemplate(int id) async {
    try {
      await _dio.delete('/api/FormTemplates/$id');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Übersetzt fachliche Antworten (409 Namens-Dublette, 404 nicht gefunden) in
  /// eine FormTemplateException mit der Backend-Meldung.
  Object _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409 || status == 404) {
      return FormTemplateException(
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Die Vorlage konnte nicht gespeichert werden'),
      );
    }
    return e;
  }
}
