import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Versicherer-Wissensbasis über das Backend (`api/Versicherer`).
@Injectable(as: VersichererRepository)
class ApiVersichererDatasource implements VersichererRepository {
  final Dio _dio;

  ApiVersichererDatasource(this._dio);

  @override
  Future<List<Versicherer>> ladeVersicherer() async {
    final response = await _dio.get('/api/Versicherer');
    final list = response.data as List;
    return list
        .map((item) => Versicherer.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
