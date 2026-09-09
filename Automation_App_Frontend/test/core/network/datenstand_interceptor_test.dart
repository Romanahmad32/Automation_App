import 'package:automation_app/core/general_classes/datenstand_signal.dart';
import 'package:automation_app/core/network/datenstand_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatenstandInterceptor interceptor;

  void antwort(String generation, {String path = '/api/Backup/uebergabe'}) {
    interceptor.onResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        headers: Headers.fromMap({
          DatenstandInterceptor.header: [generation],
        }),
      ),
      ResponseInterceptorHandler(),
    );
  }

  setUp(() {
    interceptor = DatenstandInterceptor();
    DatenstandSignal.nimmMeldung();
  });

  test(
    'Neue Generation lädt Ansichten einmal neu; alte Antworten setzen sie nicht zurück',
    () async {
      final meldungen = <String>[];
      final abo = DatenstandSignal.aenderungen.listen(meldungen.add);
      addTearDown(abo.cancel);
      antwort('0');
      antwort('1');
      antwort('0');
      antwort('1');
      await Future<void>.delayed(Duration.zero);
      expect(meldungen, hasLength(1));
      final auftrag = RequestOptions(path: '/api/Mandanten');
      interceptor.onRequest(auftrag, RequestInterceptorHandler());
      expect(auftrag.headers[DatenstandInterceptor.header], '1');
    },
  );

  test(
    'Erfolgreicher Import überlässt die Erfolgsmeldung dem Repository',
    () async {
      final meldungen = <String>[];
      final abo = DatenstandSignal.aenderungen.listen(meldungen.add);
      addTearDown(abo.cancel);
      antwort('0');
      antwort('1', path: '/api/Backup/uebergabe/uebernehmen');
      antwort('1');
      await Future<void>.delayed(Duration.zero);
      expect(meldungen, isEmpty);
      final auftrag = RequestOptions(path: '/api/Mandanten');
      interceptor.onRequest(auftrag, RequestInterceptorHandler());
      expect(auftrag.headers[DatenstandInterceptor.header], '1');
    },
  );
}
