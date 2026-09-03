import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Mandantenregister über das Backend (`api/Mandanten`). Löst den früheren
/// lokalen JSON-Speicher (mandanten.json) ab; ID-Vergabe und Namens-
/// Dublettenprüfung macht jetzt das Backend.
abstract class MandantDatasource {
  Future<List<Mandant>> loadMandanten();

  /// Ein Ausschnitt des Registers für die Mandantenliste. [suche] gilt dem
  /// ganzen Bestand, nicht dem schon geladenen Teil.
  Future<MandantenSeite> ladeSeite({
    String suche,
    int ueberspringen,
    int anzahl,
  });

  /// Die Namen aller zugeordneten Akten-Ordner — für den Zuordnungsstapel.
  Future<List<String>> ladeAktenOrdnernamen();

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
  Future<MandantenSeite> ladeSeite({
    String suche = '',
    int ueberspringen = 0,
    int anzahl = 0,
  }) async {
    final response = await _dio.get(
      '/api/Mandanten/seite',
      queryParameters: {
        if (suche.trim().isNotEmpty) 'suche': suche.trim(),
        'ueberspringen': ueberspringen,
        'anzahl': anzahl,
      },
    );
    return MandantenSeite.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<String>> ladeAktenOrdnernamen() async {
    final response = await _dio.get('/api/Mandanten/aktenordner');
    return (response.data as List).whereType<String>().toList();
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
      return MandantException(
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Der Mandant konnte nicht gespeichert werden'),
      );
    }
    return e;
  }
}
