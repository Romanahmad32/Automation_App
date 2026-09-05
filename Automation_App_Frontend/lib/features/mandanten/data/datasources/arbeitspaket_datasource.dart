import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/kein_offener_ordner.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Arbeitspakete des Mandanten-Imports über das Backend
/// (`api/Arbeitspakete`). Buch führt der Dienst: er zieht Zugeordnete und
/// Vermerkte selbst ab und sortiert stabil — hierher gehen einfach alle
/// Ordnernamen, die das Frontend gescannt hat.
abstract class ArbeitspaketDatasource {
  /// Die bisher herausgegebenen Pakete, neuestes zuerst.
  Future<List<Arbeitspaket>> ladePakete();

  /// Gibt das nächste Paket heraus und schreibt es in die Historie.
  Future<Arbeitspaket> holePaket({
    required List<String> ordnernamen,
    required int anzahl,
  });
}

@Injectable(as: ArbeitspaketDatasource)
class ApiArbeitspaketDatasource implements ArbeitspaketDatasource {
  final Dio _dio;

  ApiArbeitspaketDatasource(this._dio);

  @override
  Future<List<Arbeitspaket>> ladePakete() async {
    final response = await _dio.get('/api/Arbeitspakete');
    return [
      for (final eintrag in response.data as List)
        Arbeitspaket.fromJson(eintrag as Map<String, dynamic>),
    ];
  }

  @override
  Future<Arbeitspaket> holePaket({
    required List<String> ordnernamen,
    required int anzahl,
  }) async {
    try {
      final response = await _dio.post(
        '/api/Arbeitspakete',
        data: {'ordnernamen': ordnernamen, 'anzahl': anzahl},
        options: Options(contentType: Headers.jsonContentType),
      );
      return Arbeitspaket.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Zwei fachliche Antworten, die keine technischen Störungen sind:
  ///
  /// * **409** — es ist kein Ordner mehr offen. Der Dienst bucht dann kein
  ///   leeres Paket, weil es für immer als „nie eingelesen" in der Historie
  ///   stünde. Für den Anwalt ist das der Abschluss und kein Fehler, deshalb
  ///   ein eigener Typ statt einer Meldung.
  /// * **400** — aus dieser Anfrage lässt sich kein Paket schneiden. Der
  ///   Klartext des Dienstes gehört dem Anwalt vor die Augen.
  Object _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) {
      return KeinOffenerOrdnerException(
        backendFehlertext(e) ??
            'Es ist kein Ordner mehr offen — es gibt nichts zu holen.',
      );
    }
    if (status != 400) return e;
    return MandantException(
      backendFehlertext(e) ??
          dienstOhneAntwort(e, 'Das Arbeitspaket konnte nicht geholt werden'),
    );
  }
}
