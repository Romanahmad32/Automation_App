import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Liest Metadaten einer Word-Vorlage über das Backend aus
/// (Platzhalter-Erkennung für die Formularvorlagen-Verwaltung).
abstract class RemoteWordTemplateDatasource {
  Future<List<String>> getTemplatePlaceholders(String wordFilePath);
}

@Injectable(as: RemoteWordTemplateDatasource)
class ApiRemoteWordTemplateDatasource implements RemoteWordTemplateDatasource {
  final Dio _dio;

  ApiRemoteWordTemplateDatasource(this._dio);

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
        _serverMessage(e) ??
            'Die Platzhalter der Word-Datei konnten nicht gelesen werden',
      );
    }
  }

  /// Liest eine vom Backend gelieferte Fehlermeldung aus der Response
  /// (z. B. "Vorlage nicht gefunden: …").
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['title'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }
}
