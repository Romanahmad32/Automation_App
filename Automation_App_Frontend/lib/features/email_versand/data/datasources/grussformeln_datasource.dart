import 'package:automation_app/core/network/dienst_meldung.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/repositories/grussformeln_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die persönlichen Grußformeln über das Backend (`api/Grussformeln`).
@Injectable(as: GrussformelnRepository)
class ApiGrussformelnDatasource implements GrussformelnRepository {
  final Dio _dio;

  ApiGrussformelnDatasource(this._dio);

  @override
  Future<List<Grussformel>> ladeGrussformeln() async {
    try {
      final response = await _dio.get('/api/Grussformeln');
      final liste = response.data as List<dynamic>;
      return liste
          .whereType<Map<String, dynamic>>()
          .map(Grussformel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(
        DienstMeldung.aus(e) ??
            'Die Grußformeln konnten nicht geladen werden. '
                'Läuft der Dienst noch?',
      );
    }
  }

  @override
  Future<Grussformel> lege(Grussformel grussformel) async {
    try {
      final response = await _dio.post(
        '/api/Grussformeln',
        data: grussformel.toJson(),
      );
      return Grussformel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        DienstMeldung.aus(e) ?? 'Der Gruß konnte nicht angelegt werden.',
      );
    }
  }

  @override
  Future<Grussformel> aktualisiere(Grussformel grussformel) async {
    try {
      final response = await _dio.put(
        '/api/Grussformeln/${grussformel.id}',
        data: grussformel.toJson(),
      );
      return Grussformel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        DienstMeldung.aus(e) ?? 'Der Gruß konnte nicht gespeichert werden.',
      );
    }
  }

  @override
  Future<void> loesche(int id) async {
    try {
      await _dio.delete('/api/Grussformeln/$id');
    } on DioException catch (e) {
      throw Exception(
        DienstMeldung.aus(e) ?? 'Der Gruß konnte nicht entfernt werden.',
      );
    }
  }
}
