import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ZentralrufReplyDatasource {
  Future<ZentralrufReplyParseResult> parseReply(ZentralrufReplyInput input);
}

@Injectable(as: ZentralrufReplyDatasource)
class ApiZentralrufReplyDatasource implements ZentralrufReplyDatasource {
  final Dio _dio;

  ApiZentralrufReplyDatasource(this._dio);

  @override
  Future<ZentralrufReplyParseResult> parseReply(
    ZentralrufReplyInput input,
  ) async {
    try {
      final response = await _dio.post(
        '/api/Zentralruf/antwort/parse',
        data: {
          'emailText': input.emailText,
          'emailFileBase64': input.emailFileBase64,
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      final responseData = response.data as Map<String, dynamic>;
      return ZentralrufReplyParseResult(
        data: ZentralrufReplyData.fromJson(
          responseData['data'] as Map<String, dynamic>,
        ),
        missingFields: List<String>.from(responseData['missingFields'] ?? []),
        warnings: List<String>.from(responseData['warnings'] ?? []),
      );
    } on DioException catch (e) {
      final errorMessage = (e.response?.data is Map<String, dynamic>)
          ? (e.response!.data as Map<String, dynamic>)['errorMessage']
                as String?
          : null;
      throw Exception(
        errorMessage ??
            'Die Zentralruf-Antwort konnte nicht ausgewertet werden.',
      );
    }
  }
}
