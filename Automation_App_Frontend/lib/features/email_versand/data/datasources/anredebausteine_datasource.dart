import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/repositories/anredebausteine_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Anredeanfänge über das Backend (`api/Anredebausteine`).
@Injectable(as: AnredebausteineRepository)
class ApiAnredebausteineDatasource implements AnredebausteineRepository {
  final Dio _dio;

  ApiAnredebausteineDatasource(this._dio);

  @override
  Future<List<Anredebaustein>> ladeAnredebausteine() async {
    try {
      final response = await _dio.get('/api/Anredebausteine');
      final liste = response.data as List<dynamic>;
      return liste
          .whereType<Map<String, dynamic>>()
          .map(Anredebaustein.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            'Die Anreden konnten nicht geladen werden. Läuft der Dienst noch?',
      );
    }
  }

  @override
  Future<Anredebaustein> lege(Anredebaustein baustein) async {
    try {
      final response = await _dio.post(
        '/api/Anredebausteine',
        data: baustein.toJson(),
      );
      return Anredebaustein.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ?? 'Die Anrede konnte nicht angelegt werden.',
      );
    }
  }

  @override
  Future<Anredebaustein> aktualisiere(Anredebaustein baustein) async {
    try {
      final response = await _dio.put(
        '/api/Anredebausteine/${baustein.id}',
        data: baustein.toJson(),
      );
      return Anredebaustein.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ?? 'Die Anrede konnte nicht gespeichert werden.',
      );
    }
  }

  @override
  Future<void> loesche(int id) async {
    try {
      await _dio.delete('/api/Anredebausteine/$id');
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ?? 'Die Anrede konnte nicht entfernt werden.',
      );
    }
  }
}
