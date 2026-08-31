import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Der Register-Spiegel über das Backend (`api/Vorgaenge/register`).
///
/// Keine eigene Repository-Umsetzung dazwischen: Es gibt nichts zu übersetzen,
/// die Antwort *ist* der Stand.
///
/// Beide Wege antworten immer mit 200 und einem Stand. Ein gesperrter
/// Ablageordner ist kein Serverfehler, sondern eine Lage, die die Oberfläche in
/// einem Satz erklärt — er steht in `fehler`, nicht in einem Statuscode.
@Injectable(as: RegisterSpiegelRepository)
class ApiRegisterSpiegelDatasource implements RegisterSpiegelRepository {
  final Dio _dio;

  ApiRegisterSpiegelDatasource(this._dio);

  @override
  Future<RegisterSpiegelErgebnis> exportiere({bool erzwingen = true}) async {
    final response = await _dio.post(
      '/api/Vorgaenge/register/export',
      queryParameters: {'erzwingen': erzwingen},
    );
    return RegisterSpiegelErgebnis.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<RegisterSpiegelErgebnis> ladeStand() async {
    final response = await _dio.get('/api/Vorgaenge/register/stand');
    return RegisterSpiegelErgebnis.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
