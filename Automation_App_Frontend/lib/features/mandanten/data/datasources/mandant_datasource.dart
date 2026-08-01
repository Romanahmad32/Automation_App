import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Mandantenregister über das Backend (`api/Mandanten`). Löst den früheren
/// lokalen JSON-Speicher (mandanten.json) ab; ID-Vergabe und Namens-
/// Dublettenprüfung macht jetzt das Backend.
abstract class MandantDatasource {
  Future<List<Mandant>> loadMandanten();

  Future<Mandant> createMandant(CreateMandantRequest request);

  Future<Mandant> updateMandant(Mandant mandant);

  Future<void> deleteMandant(int id);
}

@Injectable(as: MandantDatasource)
class ApiMandantDatasource implements MandantDatasource {
  final Dio _dio;

  ApiMandantDatasource(this._dio);

  @override
  Future<List<Mandant>> loadMandanten() async {
    final response = await _dio.get('/api/Mandanten');
    final list = response.data as List;
    return list
        .map((item) => Mandant.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Mandant> createMandant(CreateMandantRequest request) async {
    try {
      final response = await _dio.post(
        '/api/Mandanten',
        data: request.toJson(),
        options: Options(contentType: Headers.jsonContentType),
      );
      return Mandant.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<Mandant> updateMandant(Mandant mandant) async {
    try {
      final response = await _dio.put(
        '/api/Mandanten/${mandant.id}',
        data: mandant.toJson(),
        options: Options(contentType: Headers.jsonContentType),
      );
      return Mandant.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> deleteMandant(int id) async {
    try {
      await _dio.delete('/api/Mandanten/$id');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Übersetzt fachliche Antworten (409 Namens-Dublette, 404 nicht gefunden) in
  /// eine MandantException mit der Backend-Meldung — gleiche Fehlersemantik wie
  /// das frühere lokale Register, das die Repository-Schicht bereits behandelt.
  Object _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409 || status == 404) {
      final data = e.response?.data;
      final message = data is String && data.isNotEmpty
          ? data
          : 'Mandant konnte nicht gespeichert werden.';
      return MandantException(message);
    }
    return e;
  }
}
