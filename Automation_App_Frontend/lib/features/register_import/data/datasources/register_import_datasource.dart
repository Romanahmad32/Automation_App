import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Übernahme der Registerhistorie über das Backend (`api/RegisterImport`).
abstract class RegisterImportDatasource {
  /// Schickt die Datei zum Dienst. Ohne [uebernehmen] wird nur geprüft und
  /// nichts geschrieben — derselbe Aufruf, derselbe Bericht.
  Future<RegisterImportBericht> importiere({
    required RegisterImportDatei datei,
    required bool uebernehmen,
  });
}

@Injectable(as: RegisterImportDatasource)
class ApiRegisterImportDatasource implements RegisterImportDatasource {
  final Dio _dio;

  ApiRegisterImportDatasource(this._dio);

  @override
  Future<RegisterImportBericht> importiere({
    required RegisterImportDatei datei,
    required bool uebernehmen,
  }) async {
    try {
      final response = await _dio.post(
        '/api/RegisterImport',
        data: datei.toJson(),
        queryParameters: {'uebernehmen': uebernehmen},
        options: Options(contentType: Headers.jsonContentType),
      );
      return RegisterImportBericht.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// 400 heißt hier nicht „kaputte Anfrage", sondern „diese Datei kann ich
  /// nicht lesen" — eine fachliche Auskunft, die der Anwalt sehen soll. Der
  /// häufigste Fall ist eine fremde Fassung: Der Erzeuger hat `version`
  /// hochgezählt, ohne dass die App sie kennt.
  Object _mapError(DioException e) {
    if (e.response?.statusCode != 400) return e;
    return RegisterException(
      backendFehlertext(e) ??
          dienstOhneAntwort(e, 'Die Registerdatei konnte nicht gelesen werden'),
    );
  }
}
