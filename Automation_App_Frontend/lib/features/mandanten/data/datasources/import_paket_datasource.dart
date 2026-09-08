import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Buchführung über die herausgegebenen Arbeitspakete
/// (`api/ImportPakete`).
///
/// Zusammengesetzt wird ein Paket im Frontend — den Bestand der Ordner kennt
/// nur der Akten-Scan. Das Backend führt darüber Buch: es vergibt die Nummer,
/// merkt sich die Ordnernamen und rechnet daraus bei jedem Lesen aus, wie weit
/// ein Paket abgearbeitet ist.
abstract class ImportPaketDatasource {
  /// Die Historie, neueste Nummer zuerst.
  Future<List<ImportPaket>> ladeImportPakete();

  /// Verbucht ein herausgegebenes Paket. Die Nummer vergibt der Dienst — sie
  /// steht erst in der Antwort.
  Future<ImportPaket> notiereImportPaket(List<String> ordnernamen);

  /// Nimmt ein versehentlich herausgegebenes, noch offenes Paket zurück.
  /// Rührt keinen Ordner an — das Paket war nur eine Buchführungszeile.
  Future<void> loescheImportPaket(int nummer);
}

@Injectable(as: ImportPaketDatasource)
class ApiImportPaketDatasource implements ImportPaketDatasource {
  final Dio _dio;

  ApiImportPaketDatasource(this._dio);

  @override
  Future<List<ImportPaket>> ladeImportPakete() async {
    final response = await _dio.get('/api/ImportPakete');
    return [
      for (final eintrag in response.data as List)
        ImportPaket.fromJson(eintrag as Map<String, dynamic>),
    ];
  }

  @override
  Future<ImportPaket> notiereImportPaket(List<String> ordnernamen) async {
    final response = await _dio.post(
      '/api/ImportPakete',
      data: {'ordnernamen': ordnernamen},
      options: Options(contentType: Headers.jsonContentType),
    );
    return ImportPaket.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> loescheImportPaket(int nummer) async {
    try {
      await _dio.delete('/api/ImportPakete/$nummer');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 409) {
        throw Exception(
          backendFehlertext(e) ??
              dienstOhneAntwort(
                e,
                'Das Arbeitspaket konnte nicht gelöscht werden',
              ),
        );
      }
      rethrow;
    }
  }
}
