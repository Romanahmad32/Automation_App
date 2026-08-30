import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// HTTP-Zugriff auf die Standardpositionen der Schadensaufstellung. Setzt das
/// Repository direkt um: Die Antwort ist bereits der Domain-Typ, es gibt
/// nichts zu übersetzen.
@Injectable(as: StandardSchadenspositionenRepository)
class ApiStandardSchadenspositionenDatasource
    implements StandardSchadenspositionenRepository {
  final Dio _dio;

  ApiStandardSchadenspositionenDatasource(this._dio);

  @override
  Future<List<StandardSchadensposition>> lade() async {
    final response = await _dio.get('/api/Settings/schadenspositionen');
    return _positionen(response.data);
  }

  @override
  Future<List<StandardSchadensposition>> speichere(
    List<StandardSchadensposition> positionen,
  ) async {
    final response = await _dio.put(
      '/api/Settings/schadenspositionen',
      data: [for (final position in positionen) position.toJson()],
      options: Options(contentType: Headers.jsonContentType),
    );
    return _positionen(response.data);
  }

  static List<StandardSchadensposition> _positionen(dynamic data) => [
    for (final eintrag in (data as List))
      StandardSchadensposition.fromJson(eintrag as Map<String, dynamic>),
  ];
}
