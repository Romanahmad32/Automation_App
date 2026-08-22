import 'package:automation_app/features/dev_simulation/domain/entities/zentralruf_antwort_typ.dart';
import 'package:automation_app/features/dev_simulation/domain/repositories/simulation_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// HTTP-Umsetzung der Entwickler-Simulation (`api/Simulation`).
@Injectable(as: SimulationRepository)
class ApiSimulationDatasource implements SimulationRepository {
  final Dio _dio;

  ApiSimulationDatasource(this._dio);

  @override
  Future<void> simuliereZentralrufAntwort({
    required String referenz,
    String? kennzeichen,
    String? unfallDatum,
    String? versichererName,
    ZentralrufAntwortTyp antwortTyp = ZentralrufAntwortTyp.versicherer,
  }) async {
    await _dio.post(
      '/api/Simulation/zentralruf-antwort',
      data: {
        'referenz': referenz,
        'kennzeichen': kennzeichen,
        'unfallDatum': unfallDatum,
        'versichererName': versichererName,
        'antwortTyp': antwortTyp.wireName,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
