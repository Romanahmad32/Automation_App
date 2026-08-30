import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Vermerke „ohne Mandantenbezug" über das Backend (`api/OrdnerStatus`).
abstract class OrdnerStatusDatasource {
  Future<List<OrdnerStatus>> ladeOrdnerStatus();

  /// Setzt [art] für alle [ordnernamen]; `null` nimmt den Vermerk zurück.
  /// Antwortet mit dem vollständigen Stand danach — eine Massenaktion über
  /// hunderte Ordner bleibt so ein Aufruf und ein Zustandswechsel.
  Future<List<OrdnerStatus>> setzeOrdnerStatus({
    required List<String> ordnernamen,
    required OrdnerStatusArt? art,
  });
}

@Injectable(as: OrdnerStatusDatasource)
class ApiOrdnerStatusDatasource implements OrdnerStatusDatasource {
  final Dio _dio;

  ApiOrdnerStatusDatasource(this._dio);

  @override
  Future<List<OrdnerStatus>> ladeOrdnerStatus() async {
    final response = await _dio.get('/api/OrdnerStatus');
    return _liste(response.data);
  }

  @override
  Future<List<OrdnerStatus>> setzeOrdnerStatus({
    required List<String> ordnernamen,
    required OrdnerStatusArt? art,
  }) async {
    final response = await _dio.put(
      '/api/OrdnerStatus',
      data: {'ordnernamen': ordnernamen, 'status': art?.wert},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _liste(response.data);
  }

  List<OrdnerStatus> _liste(Object? daten) => [
    for (final eintrag in daten as List)
      OrdnerStatus.fromJson(eintrag as Map<String, dynamic>),
  ];
}
