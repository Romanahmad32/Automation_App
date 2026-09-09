import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_nummern_stand.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Der Nummernstand eines Jahrgangs (§6.3) über das Backend
/// (`GET /api/Vorgaenge/register/nummern`).
abstract class RegisterNummernDatasource {
  /// Ohne [jahrgang] gilt das laufende Kalenderjahr (Vorgabe des Dienstes).
  Future<RegisterNummernStand> ladeNummernstand({int? jahrgang});
}

@Injectable(as: RegisterNummernDatasource)
class ApiRegisterNummernDatasource implements RegisterNummernDatasource {
  final Dio _dio;

  ApiRegisterNummernDatasource(this._dio);

  /// Eine reine Lesebefragung des Bestands — kein Word/PDF wie beim
  /// Register-Spiegel (`register_spiegel_datasource.dart`, der dafür extra
  /// zwei Minuten ansetzt). Die globale Vorgabe aus `network_module.dart`
  /// (3 s) reicht hier aus.
  @override
  Future<RegisterNummernStand> ladeNummernstand({int? jahrgang}) async {
    try {
      final response = await _dio.get(
        '/api/Vorgaenge/register/nummern',
        queryParameters: jahrgang == null ? null : {'jahrgang': jahrgang},
      );
      return RegisterNummernStand.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw RegisterException(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Der Nummernstand des Registers konnte nicht geladen werden',
            ),
      );
    }
  }
}
