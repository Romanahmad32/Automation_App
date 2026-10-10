import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Zugriff auf das Versandprotokoll (`api/EmailVersand/protokoll*`) — eigene
/// Datei, weil `email_versand_datasource.dart` sonst über das Zeilenlimit
/// wüchse. Fachlich bleibt das Protokoll Teil des Postausgangs (§4.7):
/// [ApiEmailVersandDatasource] reicht die drei Methoden aus
/// `EmailVersandRepository` unverändert an diese Datasource weiter, damit an
/// der Schnittstelle nichts anders aussieht als vorher.
abstract class EmailVersandProtokollDatasource {
  /// Was zu diesem Vorgang schon hinausgegangen ist, der jüngste Versand
  /// zuerst (§4.7) — der Nachweis, dass das Anspruchsschreiben raus ist.
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz);

  /// Je Vorgang der jüngste Versand, für die Liste in der Vorgangsverwaltung.
  /// Ein Aufruf statt einer Nachfrage je Zeile.
  Future<List<VersandEintrag>> ladeLetzteVersaende();

  /// Alles, was hinausging, über **alle** Vorgänge — das Jüngste zuerst
  /// (§4.3, Gesendet-Bereich des Posteingangs). Anders als
  /// [ladeLetzteVersaende] nicht je Vorgang eine Zeile, sondern jeder
  /// einzelne Versand, gedeckelt bei [limit].
  Future<List<VersandEintrag>> ladeAlleVersaende({int limit = 200});
}

/// Liest das Versandprotokoll über das Backend (`api/EmailVersand/protokoll*`).
@Injectable(as: EmailVersandProtokollDatasource)
class ApiEmailVersandProtokollDatasource
    implements EmailVersandProtokollDatasource {
  final Dio _dio;

  ApiEmailVersandProtokollDatasource(this._dio);

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async {
    try {
      final response = await _dio.get(
        '/api/EmailVersand/protokoll',
        queryParameters: {'referenz': referenz},
      );
      return _eintraege(response.data);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Das Versandprotokoll konnte nicht gelesen werden',
            ),
      );
    }
  }

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async {
    try {
      final response = await _dio.get('/api/EmailVersand/protokoll/letzte');
      return _eintraege(response.data);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Das Versandprotokoll konnte nicht gelesen werden',
            ),
      );
    }
  }

  @override
  Future<List<VersandEintrag>> ladeAlleVersaende({int limit = 200}) async {
    try {
      final response = await _dio.get(
        '/api/EmailVersand/protokoll/alle',
        queryParameters: {'limit': limit},
      );
      return _eintraege(response.data);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Das Versandprotokoll konnte nicht gelesen werden',
            ),
      );
    }
  }

  List<VersandEintrag> _eintraege(Object? daten) => [
    for (final eintrag in (daten as List?) ?? const [])
      VersandEintrag.fromJson(eintrag as Map<String, dynamic>),
  ];
}
