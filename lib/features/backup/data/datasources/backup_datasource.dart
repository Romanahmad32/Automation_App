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
    final data = response.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Sicherung eingespielt.';
  }
}
