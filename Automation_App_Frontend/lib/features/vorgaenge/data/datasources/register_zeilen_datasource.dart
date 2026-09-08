import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_zeilen_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Zeilen der Registeransicht über das Backend
/// (`GET /api/Vorgaenge/register/zeilen`).
///
/// Keine eigene Repository-Umsetzung dazwischen — wie beim Register-Spiegel
/// nebenan: Es gibt nichts zu übersetzen, die Antwort *ist* die Liste. Diesen
/// Weg lässt `Automation_App_Frontend/CLAUDE.md` ausdrücklich zu
/// („Braucht ein Feature diese Übersetzung nicht, entfällt die Schicht ganz").
@Injectable(as: RegisterZeilenRepository)
class ApiRegisterZeilenDatasource implements RegisterZeilenRepository {
  final Dio _dio;

  ApiRegisterZeilenDatasource(this._dio);

  @override
  Future<List<RegisterZeile>> ladeZeilen({int? jahrgang}) async {
    final response = await _dio.get(
      '/api/Vorgaenge/register/zeilen',
      queryParameters: jahrgang == null ? null : {'jahrgang': jahrgang},
    );
    return RegisterZeile.listeAusJson(response.data as Map<String, dynamic>);
  }
}
