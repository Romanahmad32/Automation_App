import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_json.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/referenz_vergeben_exception.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Vorgänge über das Backend (`api/Vorgaenge`). Löst den früheren lokalen
/// JSON-Speicher (zentralruf_vorgaenge.json) samt Alt-Migration ab — die
/// Migration übernimmt jetzt einmalig der Backend-Importdienst.
///
/// Upsert/Delete laufen pro Datensatz; die Referenz enthält Schrägstriche und
/// Leerzeichen und wird daher als Query-Parameter übergeben, nicht im Pfad.
@Injectable(as: VorgangRepository)
class ApiVorgaengeDatasource implements VorgangRepository {
  final Dio _dio;

  ApiVorgaengeDatasource(this._dio);

  @override
  Future<List<Vorgang>> loadVorgaenge() async {
    final response = await _dio.get('/api/Vorgaenge');
    final list = response.data as List;
    return list
        .map((item) => vorgangAusJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) async {
    final response = await _dio.put(
      '/api/Vorgaenge',
      data: vorgang.toJson(),
      options: Options(contentType: Headers.jsonContentType),
    );
    return vorgangAusJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteVorgang(String referenz) async {
    try {
      await _dio.delete(
        '/api/Vorgaenge',
        queryParameters: {'referenz': referenz},
      );
    } on DioException catch (e) {
      // Kein Treffer im Backend erfüllt den No-op-Vertrag (z. B. beim
      // Wiederholen eines Löschversuchs, der doch schon durchging).
      if (e.response?.statusCode != 404) rethrow;
    }
  }

  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async {
    try {
      final response = await _dio.post(
        '/api/Vorgaenge/referenz',
        queryParameters: {'von': von, 'nach': nach},
      );
      return vorgangAusJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      if (e.response?.statusCode == 409) {
        throw ReferenzVergebenException(nach);
      }
      rethrow;
    }
  }

  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async {
    try {
      final response = await _dio.post(
        '/api/Vorgaenge/abschliessen',
        queryParameters: {'referenz': referenz},
      );
      return vorgangAusJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
