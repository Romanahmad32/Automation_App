import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Liest Metadaten einer Word-Vorlage über das Backend aus
/// (Platzhalter-Erkennung für die Formularvorlagen-Verwaltung).
abstract class WordTemplateDatasource {
  Future<List<String>> getTemplatePlaceholders(String wordFilePath);
}

@Injectable(as: WordTemplateDatasource)
class ApiWordTemplateDatasource implements WordTemplateDatasource {
  final Dio _dio;

  ApiWordTemplateDatasource(this._dio);

  @override
  Future<List<String>> getTemplatePlaceholders(String wordFilePath) async {
    try {
      final response = await _dio.post(
        '/api/WordAutomation/template-placeholders',
        data: {'templateFilePath': wordFilePath},
        options: Options(contentType: Headers.jsonContentType),
      );

      final responseData = response.data as Map<String, dynamic>;
      return (responseData['placeholders'] as List?)?.cast<String>() ??
          const [];
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die Platzhalter der Word-Datei konnten nicht gelesen werden',
            ),
      );
    }
  }
}
