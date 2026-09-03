import 'package:automation_app/core/network/backend_fehlertext.dart';
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
    try {
      final response = await _dio.get('/api/EmailVersand/bereitschaft');
      return EmailVersandBereitschaft.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die Versandbereitschaft konnte nicht geprüft werden',
            ),
      );
    }
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
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Die E-Mail konnte nicht versendet werden'),
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
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Der Entwurf konnte nicht geöffnet werden'),
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
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die Anhänge aus Outlook konnten nicht gelesen werden',
            ),
      );
    }
  }

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
    try {
      final response = await _dio.get('/api/EmailVersand/signaturen');
      return [
        for (final eintrag in response.data as List)
          OutlookSignatur.fromJson(eintrag as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die Signaturen aus Outlook konnten nicht gelesen werden',
            ),
      );
    }
  }

  @override
  Future<SignaturStand> ladeSignaturStand() async {
    try {
      final response = await _dio.get('/api/EmailVersand/signaturen/stand');
      return SignaturStand.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Die Signatur konnte nicht gelesen werden'),
      );
    }
  }

  @override
  Future<SignaturStand> leseSignatur(String name) async {
    try {
      final response = await _dio.get(
        '/api/EmailVersand/signaturen/vorschau',
        queryParameters: {'name': name},
        // Die Signaturdatei samt Bildern zu lesen dauert laenger als die drei
        // Sekunden, die das NetworkModule global setzt.
        options: Options(receiveTimeout: _versandTimeout),
      );
      return SignaturStand.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ?? 'Die Signatur konnte nicht gelesen werden.',
      );
    }
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
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Die Signatur konnte nicht übernommen werden'),
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
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die formatierte Fassung konnte nicht verworfen werden',
            ),
      );
    }
  }
}
