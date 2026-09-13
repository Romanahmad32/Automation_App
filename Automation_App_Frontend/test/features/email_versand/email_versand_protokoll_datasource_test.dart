import 'dart:convert';
import 'dart:typed_data';

import 'package:automation_app/features/email_versand/data/datasources/email_versand_protokoll_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein `HttpClientAdapter`, der nie wirklich ins Netz geht — er beantwortet
/// jede Anfrage mit dem im Test vorgegebenen [antwort]. Es gibt in dieser
/// Codebasis noch keinen Mocking-Baustein für Dio-Datasources; das ist der
/// kleinste Weg ohne eine neue Abhängigkeit.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.antwort);

  final ResponseBody Function(RequestOptions options) antwort;

  /// Die zuletzt gestellte Anfrage — für die Prüfung von Pfad und
  /// Query-Parametern.
  RequestOptions? letzteAnfrage;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    letzteAnfrage = options;
    return antwort(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? daten, int status) => ResponseBody.fromString(
  jsonEncode(daten),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test('ladeAlleVersaende liest Pfad, Limit und die Liste', () async {
    final adapter = _FakeAdapter(
      (options) => _json([
        {
          'vorgangReferenz': '84/26 C03',
          'gesendetAm': '2026-08-25T14:12:00.000Z',
          'weg': 'Direktversand',
          'absender': 'kanzlei@example.de',
          'empfaenger': ['mandant@example.de'],
          'kopie': <String>[],
          'betreff': 'Ihre Verkehrsunfallsache',
          'anhaenge': <String>[],
          'imGesendetOrdner': true,
        },
      ], 200),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final datasource = ApiEmailVersandProtokollDatasource(dio);

    final eintraege = await datasource.ladeAlleVersaende(limit: 50);

    expect(adapter.letzteAnfrage?.path, '/api/EmailVersand/protokoll/alle');
    expect(adapter.letzteAnfrage?.queryParameters['limit'], 50);
    expect(eintraege, hasLength(1));
    expect(eintraege.single.vorgangReferenz, '84/26 C03');
    expect(eintraege.single.empfaenger, ['mandant@example.de']);
  });

  test('ladeAlleVersaende fragt ohne Angabe mit dem Limit 200 an', () async {
    final adapter = _FakeAdapter((options) => _json(<Object?>[], 200));
    final dio = Dio()..httpClientAdapter = adapter;
    final datasource = ApiEmailVersandProtokollDatasource(dio);

    await datasource.ladeAlleVersaende();

    expect(adapter.letzteAnfrage?.queryParameters['limit'], 200);
  });

  test('meldet einen deutschen Fehler, wenn der Dienst ablehnt', () async {
    final adapter = _FakeAdapter(
      (options) => _json({'detail': 'Datenbank nicht erreichbar'}, 500),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final datasource = ApiEmailVersandProtokollDatasource(dio);

    await expectLater(
      () => datasource.ladeAlleVersaende(),
      throwsA(
        predicate<Object>(
          (e) => e.toString().contains('Datenbank nicht erreichbar'),
        ),
      ),
    );
  });
}
