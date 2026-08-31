import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// HTTP-Zugriff auf die Datensicherung des Backends (`api/Backup`) — die
/// data-seitige Umsetzung des [BackupRepository]-Ports.
@Injectable(as: BackupRepository)
class ApiBackupDatasource implements BackupRepository {
  final Dio _dio;

  ApiBackupDatasource(this._dio);

  // Sicherung/Wiederherstellung dürfen länger dauern als die knappen
  // Default-Timeouts (3 s): Migration beim Import, größere Datenbanken.
  static const Duration _timeout = Duration(minutes: 5);

  @override
  Future<List<int>> exportDatenbank() async {
    final response = await _dio.get<List<int>>(
      '/api/Backup/export',
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: _timeout,
      ),
    );
    return response.data ?? const <int>[];
  }

  @override
  Future<String> importDatenbank(String dateipfad) async {
    final dateiname = dateipfad.split(RegExp(r'[\\/]')).last;
    final formData = FormData.fromMap({
      // Feldname muss zum IFormFile-Parameter `datei` des Backends passen.
      'datei': await MultipartFile.fromFile(dateipfad, filename: dateiname),
    });
    final response = await _dio.post(
      '/api/Backup/import',
      data: formData,
      options: Options(sendTimeout: _timeout, receiveTimeout: _timeout),
    );
    return _meldung(response.data, 'Sicherung eingespielt.');
  }

  @override
  Future<UebergabeStand> uebergabeStand() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/Backup/uebergabe',
    );
    final data = response.data;
    return data == null ? UebergabeStand.still : UebergabeStand.fromJson(data);
  }

  @override
  Future<String> uebernehmeStand() async {
    final response = await _dio.post(
      '/api/Backup/uebergabe/uebernehmen',
      // Einspielen heißt Datenbank tauschen und migrieren — dieselbe
      // Größenordnung wie ein Import von Hand, nicht die 3-Sekunden-Vorgabe.
      options: Options(sendTimeout: _timeout, receiveTimeout: _timeout),
    );
    return _meldung(response.data, 'Stand übernommen.');
  }

  @override
  Future<void> quittiereSicherungsfehler() =>
      _dio.post<void>('/api/Backup/sicherungsstand/quittieren');

  /// Beide Einspielwege antworten mit einem `message`-Feld; der Rückfall greift
  /// nur, wenn das Backend etwas anderes schickt als vereinbart.
  String _meldung(Object? data, String rueckfall) =>
      data is Map && data['message'] is String
      ? data['message'] as String
      : rueckfall;
}
