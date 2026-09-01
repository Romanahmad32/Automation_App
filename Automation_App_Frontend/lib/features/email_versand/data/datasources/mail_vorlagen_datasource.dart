import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/repositories/mail_vorlagen_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die Mail-Textvorlagen über das Backend (`api/MailVorlagen`).
@Injectable(as: MailVorlagenRepository)
class ApiMailVorlagenDatasource implements MailVorlagenRepository {
  final Dio _dio;

  ApiMailVorlagenDatasource(this._dio);

  @override
  Future<List<MailVorlage>> ladeVorlagen() async {
    try {
      final response = await _dio.get('/api/MailVorlagen');
      final liste = response.data as List<dynamic>;
      return liste
          .whereType<Map<String, dynamic>>()
          .map(MailVorlage.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _meldung(e) ??
            'Die Mail-Vorlagen konnten nicht geladen werden. '
                'Läuft der Dienst noch?',
      );
    }
  }

  @override
  Future<MailVorlage> lege(MailVorlage vorlage) async {
    try {
      final response = await _dio.post(
        '/api/MailVorlagen',
        data: vorlage.toJson(),
      );
      return MailVorlage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        _meldung(e) ?? 'Die Vorlage konnte nicht angelegt werden.',
      );
    }
  }

  @override
  Future<MailVorlage> aktualisiere(MailVorlage vorlage) async {
    try {
      final response = await _dio.put(
        '/api/MailVorlagen/${vorlage.id}',
        data: vorlage.toJson(),
      );
      return MailVorlage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        _meldung(e) ?? 'Die Vorlage konnte nicht gespeichert werden.',
      );
    }
  }

  @override
  Future<void> loesche(int id) async {
    try {
      await _dio.delete('/api/MailVorlagen/$id');
    } on DioException catch (e) {
      throw Exception(
        _meldung(e) ?? 'Die Vorlage konnte nicht entfernt werden.',
      );
    }
  }

  /// Der Klartext des Dienstes, wenn er einen geschickt hat — bei 409 steht
  /// dort, welcher Name schon vergeben ist. Ohne ihn bliebe nur „Fehler 409".
  String? _meldung(DioException e) {
    final daten = e.response?.data;
    if (daten is String && daten.trim().isNotEmpty) return daten.trim();
    return null;
  }
}
