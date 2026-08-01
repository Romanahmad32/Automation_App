import 'dart:io';

import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ZentralrufDatasource {
  Future<ZentralrufPrefillResult> prefillForm(ZentralrufRequest request);
}

@Injectable(as: ZentralrufDatasource)
class ApiZentralrufDatasource implements ZentralrufDatasource {
  final Dio _dio;

  ApiZentralrufDatasource(this._dio);

  @override
  Future<ZentralrufPrefillResult> prefillForm(ZentralrufRequest request) async {
    try {
      final response = await _dio.post(
        '/api/Zentralruf/prefill',
        data: {
          'auftragsnummer': request.auftragsnummer,
          'auftragsjahr': request.auftragsjahr,
          'abteilung': request.abteilung,
          'kennzeichenSchaediger': request.kennzeichenSchaediger,
          'schadentag':
              '${request.schadentag.year.toString().padLeft(4, '0')}-'
              '${request.schadentag.month.toString().padLeft(2, '0')}-'
              '${request.schadentag.day.toString().padLeft(2, '0')}',
          if (request.referenz?.trim().isNotEmpty ?? false)
            'referenz': request.referenz!.trim(),
          if (request.geschaedigter case final geschaedigter?)
            'geschaedigter': {
              'name': geschaedigter.name,
              'strasseHausnummer': geschaedigter.strasseHausnummer,
              'postleitzahl': geschaedigter.postleitzahl,
              'ort': geschaedigter.ort,
              'kennzeichen': geschaedigter.kennzeichen,
            },
          if (request.anfrager case final anfrager?)
            'anfrager': {
              'personentyp': anfrager.personentyp,
              'name': anfrager.name,
              'strasseHausnummer': anfrager.strasseHausnummer,
              'postleitzahl': anfrager.postleitzahl,
              'ort': anfrager.ort,
              'emailAdresse': anfrager.emailAdresse,
              'telefonnummer': anfrager.telefonnummer,
            },
        },
        options: Options(
          contentType: Headers.jsonContentType,
          // Browserstart und ggf. einmalige Browser-Installation dauern deutlich
          // länger als das globale Timeout.
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      final responseData = response.data as Map<String, dynamic>;
      return ZentralrufPrefillResult(
        referenz: responseData['referenz'] as String? ?? '',
        filledFields: List<String>.from(responseData['filledFields'] ?? []),
        skippedFields: List<String>.from(responseData['skippedFields'] ?? []),
      );
    } on DioException catch (e) {
      // Verbindungsfehler (Backend läuft nicht) für den nicht-technischen
      // Anwender verständlich formulieren statt der Dio-Rohmeldung.
      if (_isConnectionError(e)) {
        throw Exception(
          'Der Hintergrunddienst der Anwendung ist nicht erreichbar. '
          'Bitte schließen Sie die Anwendung vollständig und starten Sie sie neu. '
          'Tritt der Fehler erneut auf, wenden Sie sich an Ihren Administrator.',
        );
      }
      throw Exception(
        'Das Zentralruf-Formular konnte nicht geöffnet oder vorausgefüllt werden',
      );
    }
  }

  static bool _isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.error is SocketException;
  }
}
