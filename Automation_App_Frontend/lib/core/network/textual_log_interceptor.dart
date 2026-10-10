import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Wie Dios [LogInterceptor], protokolliert aber den Response-Body nur, wenn er
/// textuell ist (JSON/Text). Binär-Antworten wie die PDF-Konvertierung würden
/// sonst als riesige Byte-Liste ([..., 37, 37, 69, 79, 70] = "%%EOF") ins
/// Terminal geschrieben.
///
/// Eine Anfrage kann ihre Antwort ganz ausnehmen: [keinAntwortProtokoll] in
/// `Options.extra`, mit einer Bezeichnung dessen, was ausgelassen wird — für
/// Mandantendaten (Posteingang, Vollmacht-Vorschau), und für Antworten, die
/// so groß sind, dass sie das Protokoll fluten.
class TextualLogInterceptor extends Interceptor {
  /// Schlüssel in `Options.extra`; der Wert sagt, was nicht protokolliert wird.
  static const keinAntwortProtokoll = 'keinAntwortProtokoll';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('*** Request ***');
    debugPrint('uri: ${options.uri}');
    debugPrint('method: ${options.method}');
    options.headers.forEach((k, v) => debugPrint('$k: $v'));
    if (options.data != null) debugPrint('body: ${options.data}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('*** Response ***');
    debugPrint('uri: ${response.requestOptions.uri}');
    debugPrint('statusCode: ${response.statusCode}');
    response.headers.forEach((k, v) => debugPrint('$k: ${v.join(', ')}'));
    final ausgenommen = response.requestOptions.extra[keinAntwortProtokoll];
    if (ausgenommen is String) {
      debugPrint('body: <$ausgenommen, nicht protokolliert>');
    } else if (_isTextual(response.headers)) {
      debugPrint('body: ${response.data}');
    } else {
      final type =
          response.headers.value(Headers.contentTypeHeader) ?? 'binary';
      debugPrint('body: <$type, nicht protokolliert>');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('*** DioException ***');
    debugPrint('uri: ${err.requestOptions.uri}');
    debugPrint('$err');
    if (err.response != null && _isTextual(err.response!.headers)) {
      debugPrint('body: ${err.response!.data}');
    }
    handler.next(err);
  }

  bool _isTextual(Headers headers) {
    final contentType =
        headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    return contentType.contains('json') ||
        contentType.contains('text') ||
        contentType.contains('xml');
  }
}
