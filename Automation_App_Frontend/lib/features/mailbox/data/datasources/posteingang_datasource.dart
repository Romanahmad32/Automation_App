import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: PosteingangRepository)
class ApiPosteingangDatasource implements PosteingangRepository {
  final Dio _dio;
  CancelToken? _seite;
  CancelToken? _inhalt;
  ApiPosteingangDatasource(this._dio);

  @override
  Future<PosteingangSeite> ladeSeite({String? cursor}) async {
    _seite?.cancel();
    final token = _seite = CancelToken();
    return PosteingangSeite.fromJson(
      await _get('/api/mailbox/nachrichten', token, query: {'cursor': ?cursor}),
    );
  }

  @override
  Future<PosteingangInhalt> ladeInhalt(String id) async {
    _inhalt?.cancel();
    final token = _inhalt = CancelToken();
    return PosteingangInhalt.fromJson(
      await _get('/api/mailbox/nachrichten/$id', token),
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    CancelToken token, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        cancelToken: token,
        options: Options(
          receiveTimeout: const Duration(seconds: 50),
          extra: {'keinAntwortProtokoll': true},
        ),
      );
      return response.data!;
    } on DioException catch (error) {
      final body = error.response?.data;
      throw PosteingangFehler(
        body is Map
            ? (body['detail'] ??
                      body['title'] ??
                      'Posteingang konnte nicht geladen werden.')
                  .toString()
            : 'Posteingang nicht erreichbar. Bitte die Verbindung prüfen und erneut laden.',
      );
    }
  }

  @override
  void abbrechen() {
    _seite?.cancel();
    _inhalt?.cancel();
  }
}
