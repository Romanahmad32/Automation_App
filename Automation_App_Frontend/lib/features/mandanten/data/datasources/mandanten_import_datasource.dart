import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Der Mandantenimport über das Backend (`api/MandantenImport`).
abstract class MandantenImportDatasource {
  /// Schickt die Datei zum Dienst. Ohne [uebernehmen] wird nur geprüft und
  /// nichts geschrieben — derselbe Aufruf, derselbe Bericht.
  Future<ImportBericht> importiere({
    required MandantenImportDatei datei,
    required bool uebernehmen,
  });
}

@Injectable(as: MandantenImportDatasource)
class ApiMandantenImportDatasource implements MandantenImportDatasource {
  final Dio _dio;

  ApiMandantenImportDatasource(this._dio);

  @override
  Future<ImportBericht> importiere({
    required MandantenImportDatei datei,
    required bool uebernehmen,
  }) async {
    try {
      final response = await _dio.post(
        '/api/MandantenImport',
        data: datei.toJson(),
        queryParameters: {'uebernehmen': uebernehmen},
        options: Options(contentType: Headers.jsonContentType),
      );
      return ImportBericht.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// 400 heißt hier nicht „kaputte Anfrage", sondern „diese Datei kann ich
  /// nicht lesen" — eine fachliche Auskunft, die der Anwender sehen soll.
  Object _mapError(DioException e) {
    if (e.response?.statusCode != 400) return e;
    final daten = e.response?.data;
    return MandantException(
      daten is String && daten.isNotEmpty
          ? daten
          : 'Die Importdatei konnte nicht gelesen werden.',
    );
  }
}
