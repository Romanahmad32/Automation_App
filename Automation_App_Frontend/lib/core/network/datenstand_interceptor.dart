import 'package:automation_app/core/general_classes/datenstand_signal.dart';
import 'package:dio/dio.dart';

/// Jeder Auftrag trägt die Generation, auf deren Basis die Oberfläche arbeitet.
class DatenstandInterceptor extends Interceptor {
  static const header = 'X-App-Datenstand';
  String? _generation;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_generation != null) options.headers[header] = _generation;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _pruefe(
      response.headers,
      melden: !const [
        '/api/Backup/import',
        '/api/Backup/uebergabe/uebernehmen',
      ].contains(response.requestOptions.path),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) _pruefe(err.response!.headers);
    handler.next(err);
  }

  void _pruefe(Headers headers, {bool melden = true}) {
    final neu = headers.value(header);
    if (neu == null) return;
    final vorher = _generation;
    // Verspätete Antworten älterer Leseaufrufe dürfen die Generation nicht zurücksetzen.
    if (vorher != null &&
        (int.tryParse(neu) ?? -1) < (int.tryParse(vorher) ?? -1)) {
      return;
    }
    _generation = neu;
    if (melden && vorher != null && vorher != neu) {
      DatenstandSignal.uebernommen('Datenstand neu geladen.');
    }
  }
}
