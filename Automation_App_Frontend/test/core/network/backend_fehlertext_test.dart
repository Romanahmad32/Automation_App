import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

RequestOptions get _requestOptions => RequestOptions(path: '/api/Test');

DioException _exceptionMit({Object? data, int? statusCode}) {
  final requestOptions = _requestOptions;
  return DioException(
    requestOptions: requestOptions,
    response: statusCode == null && data == null
        ? null
        : Response(
            requestOptions: requestOptions,
            data: data,
            statusCode: statusCode,
          ),
  );
}

void main() {
  group('backendFehlertext', () {
    test('liest "detail" aus ProblemDetails', () {
      final exception = _exceptionMit(
        data: {'detail': 'Der Name ist bereits vergeben.', 'title': 'x'},
        statusCode: 409,
      );

      expect(backendFehlertext(exception), 'Der Name ist bereits vergeben.');
    });

    test('faellt auf "title" zurueck, wenn "detail" fehlt', () {
      final exception = _exceptionMit(
        data: {'title': 'Namenskonflikt'},
        statusCode: 409,
      );

      expect(backendFehlertext(exception), 'Namenskonflikt');
    });

    test('faellt auf "message" zurueck (ok/errorCode-DTOs)', () {
      final exception = _exceptionMit(
        data: {'success': false, 'message': 'Vorlage nicht gefunden'},
        statusCode: 404,
      );

      expect(backendFehlertext(exception), 'Vorlage nicht gefunden');
    });

    test('liest einen nackten String-Body', () {
      final exception = _exceptionMit(
        data: 'Die Datei ist kein lesbares Sicherungsarchiv.',
        statusCode: 400,
      );

      expect(
        backendFehlertext(exception),
        'Die Datei ist kein lesbares Sicherungsarchiv.',
      );
    });

    test('liest Bytes als UTF-8', () {
      final exception = _exceptionMit(
        data: 'Konvertierung fehlgeschlagen'.codeUnits,
        statusCode: 500,
      );

      expect(backendFehlertext(exception), 'Konvertierung fehlgeschlagen');
    });

    test('faellt auf den Statuscode zurueck, wenn nichts lesbares da ist', () {
      final exception = _exceptionMit(data: null, statusCode: 500);

      expect(
        backendFehlertext(exception),
        'Der Dienst hat mit Status 500 geantwortet.',
      );
    });

    test('gibt null zurueck, wenn der Dienst gar nicht geantwortet hat', () {
      final exception = _exceptionMit();

      expect(backendFehlertext(exception), isNull);
    });

    test('ignoriert leere Felder und faellt weiter durch', () {
      final exception = _exceptionMit(
        data: {'detail': '', 'title': '  ', 'message': 'Der echte Grund'},
        statusCode: 400,
      );

      expect(backendFehlertext(exception), 'Der echte Grund');
    });
  });
}
