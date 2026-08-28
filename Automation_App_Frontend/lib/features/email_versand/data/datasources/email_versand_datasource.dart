import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Postausgang über das Backend (`api/EmailVersand`).
@Injectable(as: EmailVersandRepository)
class ApiEmailVersandDatasource implements EmailVersandRepository {
  /// Anhänge lesen, Verbindung aufbauen, Anmelden, Übertragen — das dauert
  /// länger als die 3 Sekunden, die der `NetworkModule` global setzt. Gilt auch
  /// für den Entwurf: Ein kalt startendes Outlook lässt ebenso lange warten.
  static const Duration _versandTimeout = Duration(seconds: 120);

  final Dio _dio;

  ApiEmailVersandDatasource(this._dio);

  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() async {
    final response = await _dio.get('/api/EmailVersand/bereitschaft');
    return EmailVersandBereitschaft.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<EmailVersandErgebnis> sende(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/EmailVersand/senden',
        data: entwurf.toJson(absenderName),
        options: Options(receiveTimeout: _versandTimeout),
      );
      return EmailVersandErgebnis.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        _serverMeldung(e) ??
            'Die E-Mail konnte nicht versendet werden. Läuft der Dienst noch?',
      );
    }
  }

  @override
  Future<EmailEntwurfErgebnis> oeffneEntwurf(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/EmailVersand/entwurf',
        data: entwurf.toJson(absenderName),
        options: Options(receiveTimeout: _versandTimeout),
      );
      return EmailEntwurfErgebnis.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        _serverMeldung(e) ??
            'Der Entwurf konnte nicht geöffnet werden. Läuft der Dienst noch?',
      );
    }
  }

  @override
  Future<void> waermeEntwurfVor() async {
    try {
      await _dio.post('/api/EmailVersand/entwurf/vorwaermen');
    } on DioException {
      // Vorwärmen ist eine Bequemlichkeit, kein Schritt des Ablaufs. Schlägt es
      // fehl, öffnet der Entwurf eben so langsam wie vorher.
    }
  }

  @override
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() async {
    try {
      final response = await _dio.get(
        '/api/EmailVersand/outlook/anhaenge',
        // Steht Outlook noch nicht, wird es hier gestartet — das dauert.
        options: Options(receiveTimeout: _versandTimeout),
      );
      return OutlookAnhaenge.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        _serverMeldung(e) ??
            'Die Anhänge aus Outlook konnten nicht gelesen werden.',
      );
    }
  }

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async {
    final response = await _dio.get(
      '/api/EmailVersand/protokoll',
      queryParameters: {'referenz': referenz},
    );
    return _eintraege(response.data);
  }

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async {
    final response = await _dio.get('/api/EmailVersand/protokoll/letzte');
    return _eintraege(response.data);
  }

  List<VersandEintrag> _eintraege(Object? daten) => [
    for (final eintrag in (daten as List?) ?? const [])
      VersandEintrag.fromJson(eintrag as Map<String, dynamic>),
  ];

  @override
  Future<OutlookStand> ladeOutlookStand() async {
    try {
      final response = await _dio.get('/api/EmailVersand/outlook/stand');
      return OutlookStand.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      // Ohne Antwort wird nichts behauptet und nichts abgeschaltet: Die
      // Oberflaeche bleibt, wie sie ohne diese Auskunft waere.
      return OutlookStand.unbekannt;
    }
  }

  @override
  Future<void> verwirfAnhang(String pfad) async {
    try {
      await _dio.delete(
        '/api/EmailVersand/outlook/anhaenge',
        queryParameters: {'pfad': pfad},
      );
    } on DioException {
      // Der Vorschlag ist aus der Reihe, das ist die Hauptsache. Bleibt die
      // Datei liegen, holt sie spätestens das Aufräumen beim nächsten Start.
    }
  }

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async {
    final response = await _dio.get('/api/EmailVersand/signaturen');
    return [
      for (final eintrag in response.data as List)
        OutlookSignatur.fromJson(eintrag as Map<String, dynamic>),
    ];
  }

  @override
  Future<SignaturStand> ladeSignaturStand() async {
    final response = await _dio.get('/api/EmailVersand/signaturen/stand');
    return SignaturStand.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<SignaturStand> uebernimmSignatur(String name) async {
    try {
      final response = await _dio.post(
        '/api/EmailVersand/signaturen/uebernehmen',
        data: {'name': name},
        // Bilder lesen und ablegen dauert laenger als die 3 Sekunden, die der
        // NetworkModule global setzt.
        options: Options(receiveTimeout: _versandTimeout),
      );
      return SignaturStand.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        _serverMeldung(e) ?? 'Die Signatur konnte nicht übernommen werden.',
      );
    }
  }

  @override
  Future<SignaturStand> verwirfSignaturFormat() async {
    try {
      final response = await _dio.delete('/api/EmailVersand/signaturen/format');
      return SignaturStand.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        _serverMeldung(e) ??
            'Die formatierte Fassung konnte nicht verworfen werden.',
      );
    }
  }

  /// Der Grund im Klartext aus den ProblemDetails des Backends. Genau dieser
  /// Text landet vor dem Anwalt — er sagt ihm, was zu tun ist (Anhang
  /// schließen, neu anmelden), was eine Statusnummer nie könnte.
  String? _serverMeldung(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['title'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}
