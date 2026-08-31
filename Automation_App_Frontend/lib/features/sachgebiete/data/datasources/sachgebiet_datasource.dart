import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/repositories/sachgebiet_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// HTTP-Zugriff auf den Sachgebietskatalog (`GET /api/Sachgebiete`). Setzt das
/// Repository direkt um — es gibt nichts zu übersetzen, die Antwort ist bereits
/// der Domain-Typ.
@Injectable(as: SachgebietRepository)
class ApiSachgebietDatasource implements SachgebietRepository {
  final Dio _dio;

  ApiSachgebietDatasource(this._dio);

  @override
  Future<List<Sachgebiet>> ladeSachgebiete() async {
    final response = await _dio.get<List<dynamic>>('/api/Sachgebiete');
    return [
      for (final eintrag in response.data ?? const [])
        Sachgebiet.fromJson(eintrag as Map<String, dynamic>),
    ];
  }
}
