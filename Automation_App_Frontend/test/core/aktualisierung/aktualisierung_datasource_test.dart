import 'dart:convert';
import 'dart:typed_data';

import 'package:automation_app/core/aktualisierung/data/datasources/aktualisierung_datasource.dart';
import 'package:automation_app/core/aktualisierung/data/repositories/aktualisierung_repository_impl.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein `HttpClientAdapter`, der nie ins Netz geht — er beantwortet jede
/// Anfrage mit [antwort] und merkt sich die Anfragen (wie in
/// `email_versand_protokoll_datasource_test.dart`).
class AttrappenAdapter implements HttpClientAdapter {
  AttrappenAdapter(this.antwort);

  final ResponseBody Function(RequestOptions options) antwort;
  final List<RequestOptions> anfragen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    anfragen.add(options);
    return antwort(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object? daten, int status) => ResponseBody.fromString(
  jsonEncode(daten),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// So antwortet der Dienst (`AktualisierungsStandDto`, camelCase).
const Map<String, Object?> standJson = {
  'laufendeVersion': '1.3.0',
  'neueVersion': '1.4.0',
  'zustand': 'laedt',
  'geladenBytes': 56623104,
  'gesamtBytes': 96468992,
  'meldung': null,
  'fehlerArt': null,
  'downloadUrl': 'https://example.invalid/Automation_App_Setup_1.4.0.exe',
  'letzteAktualisierung': {'zielVersion': '1.3.0', 'erfolgreich': true},
};

void main() {
  late AttrappenAdapter adapter;
  late ApiAktualisierungDatasource datasource;

  void antworte(ResponseBody Function(RequestOptions options) antwort) {
    adapter = AttrappenAdapter(antwort);
    datasource = ApiAktualisierungDatasource(
      Dio()..httpClientAdapter = adapter,
    );
  }

  test('liest den ganzen Stand aus GET api/Aktualisierung', () async {
    antworte((_) => json(standJson, 200));

    final stand = await datasource.stand();

    expect(adapter.anfragen.single.method, 'GET');
    expect(adapter.anfragen.single.path, '/api/Aktualisierung');
    expect(stand.zustand, AktualisierungsZustand.laedt);
    expect(stand.neueVersion, '1.4.0');
    expect(stand.prozent, 58);
    expect(stand.downloadUrl, endsWith('Setup_1.4.0.exe'));
    expect(stand.letzteAktualisierung?.zielVersion, '1.3.0');
    expect(stand.letzteAktualisierung?.erfolgreich, isTrue);
  });

  test('jeder Schritt ist ein POST auf seinen Pfad', () async {
    antworte(
      (options) => options.path.endsWith('quittieren')
          ? ResponseBody.fromString('', 204)
          : json(standJson, options.path.endsWith('pruefen') ? 200 : 202),
    );

    await datasource.pruefen();
    await datasource.herunterladen();
    await datasource.abbrechen();
    await datasource.installieren();
    await datasource.ergebnisQuittieren();

    expect(adapter.anfragen.map((a) => a.method).toSet(), {'POST'});
    expect(adapter.anfragen.map((a) => a.path), [
      '/api/Aktualisierung/pruefen',
      '/api/Aktualisierung/herunterladen',
      '/api/Aktualisierung/abbrechen',
      '/api/Aktualisierung/installieren',
      '/api/Aktualisierung/ergebnis-quittieren',
    ]);
    expect(
      adapter.anfragen.first.receiveTimeout,
      ApiAktualisierungDatasource.pruefFrist,
      reason: 'Die Prüfung im Dienst darf zehn Sekunden dauern.',
    );
  });

  test('liest die Ursache eines Fehlers aus fehlerArt', () async {
    for (final MapEntry(key: wert, value: art) in {
      'verbindung': AktualisierungsFehlerArt.verbindung,
      'pruefung': AktualisierungsFehlerArt.pruefung,
      'sonstig': AktualisierungsFehlerArt.sonstig,
      'neu-erfunden': AktualisierungsFehlerArt.sonstig,
    }.entries) {
      antworte(
        (_) => json({
          ...standJson,
          'zustand': 'fehler',
          'meldung': 'Ein Satz des Dienstes.',
          'fehlerArt': wert,
        }, 200),
      );

      final stand = await datasource.stand();

      expect(stand.zustand, AktualisierungsZustand.fehler, reason: wert);
      expect(stand.fehlerArt, art, reason: wert);
    }
  });

  test('ohne Fehler steht keine Ursache', () async {
    antworte((_) => json(standJson, 200));

    expect((await datasource.stand()).fehlerArt, isNull);
  });

  test('ein unbekannter Zustand gilt als unbekannt', () async {
    antworte((_) => json({...standJson, 'zustand': 'neu-erfunden'}, 200));

    final stand = await datasource.stand();

    expect(stand.zustand, AktualisierungsZustand.unbekannt);
    expect(stand.updateInSicht, isFalse);
  });

  test('ein 409 kommt mit dem Satz aus detail als Failure an', () async {
    antworte(
      (_) => json({
        'title': 'Conflict',
        'status': 409,
        'detail':
            'Die neue Version ist noch nicht vollständig heruntergeladen.',
      }, 409),
    );
    final repository = AktualisierungRepositoryImpl(datasource);

    final ergebnis = await repository.installieren();

    switch (ergebnis) {
      case Left(:final value):
        expect(
          value.message,
          'Die neue Version ist noch nicht vollständig heruntergeladen.',
        );
      case Right():
        fail('Ein 409 darf nicht als Erfolg ankommen.');
    }
  });
}
