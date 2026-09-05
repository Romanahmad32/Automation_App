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
}
