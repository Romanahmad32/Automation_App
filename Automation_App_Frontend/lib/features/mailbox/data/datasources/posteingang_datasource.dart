import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: PosteingangRepository)
class ApiPosteingangDatasource implements PosteingangRepository {
  /// Ein Anhang oder eine ganze `.eml` kann groß sein und läuft über dieselbe
  /// einzelne IMAP-Verbindung wie das Blättern — die 50 s der Liste reichen
  /// dafür nicht.
  static const Duration downloadWartezeit = Duration(seconds: 90);

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

  @override
  Future<PosteingangAnhangAblage> ladeAnhang(String id, String anhangId) async {
    return PosteingangAnhangAblage.fromJson(
      await _get(
        '/api/mailbox/nachrichten/$id/anhaenge/$anhangId',
        // Ein eigener, nirgends gemerkter Token: Über `abbrechen()` bricht das
        // Blättern sonst den laufenden Download mit ab.
        CancelToken(),
        wartezeit: downloadWartezeit,
      ),
    );
  }

  @override
  Future<PosteingangAnhangAblage> ladeEml(String id) async {
    return PosteingangAnhangAblage.fromJson(
      await _get(
        '/api/mailbox/nachrichten/$id/eml',
        CancelToken(),
        wartezeit: downloadWartezeit,
      ),
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    CancelToken token, {
    Map<String, dynamic>? query,
    Duration wartezeit = const Duration(seconds: 50),
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        cancelToken: token,
        options: Options(
          receiveTimeout: wartezeit,
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
