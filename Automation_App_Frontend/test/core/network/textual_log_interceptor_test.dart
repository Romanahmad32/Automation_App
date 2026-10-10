import 'package:automation_app/core/network/textual_log_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was der Debug-Logger von einer Antwort ins Protokoll schreibt — und was
/// eine Anfrage davon ausnehmen kann (Mandantendaten, große Antworten).
void main() {
  late List<String> zeilen;
  late DebugPrintCallback vorher;

  setUp(() {
    zeilen = [];
    vorher = debugPrint;
    debugPrint = (message, {wrapWidth}) => zeilen.add(message ?? '');
  });

  tearDown(() => debugPrint = vorher);

  void antwort({Map<String, dynamic> extra = const {}}) {
    TextualLogInterceptor().onResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(
          path: '/api/Vollmacht/vorschau',
          extra: extra,
        ),
        statusCode: 200,
        data: {'status': 'erstellt', 'pdf': 'JVBERi0xLjcK'},
        headers: Headers.fromMap({
          Headers.contentTypeHeader: [Headers.jsonContentType],
        }),
      ),
      ResponseInterceptorHandler(),
    );
  }

  test('eine ausgenommene Antwort nennt nur, was ausgelassen wurde', () {
    antwort(
      extra: {
        TextualLogInterceptor.keinAntwortProtokoll: 'Seite der Vollmacht',
      },
    );

    expect(
      zeilen,
      contains('body: <Seite der Vollmacht, nicht protokolliert>'),
    );
    expect(zeilen.join('\n'), isNot(contains('JVBERi0')));
  });

  test('ohne Ausnahme steht der Body einer JSON-Antwort im Protokoll', () {
    antwort();

    expect(zeilen.join('\n'), contains('JVBERi0'));
  });
}
