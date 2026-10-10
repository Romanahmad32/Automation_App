import 'package:automation_app/core/network/textual_log_interceptor.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Der HTTP-Vertrag der Vollmacht (`api/Vollmacht`, dazu `api/Mandanten/{id}`),
/// roh: wirft bei einem Fehler die [DioException] weiter. Die Übersetzung in
/// `Either<Failure, T>` liegt in `VollmachtRepositoryImpl`.
abstract class VollmachtDatasource {
  Future<VollmachtVorlagenStand> ladeVorlagen();

  /// Null, wenn der Dienst den Mandanten nicht kennt (404).
  Future<Mandant?> ladeMandant(int id);

  Future<VollmachtErgebnis> drucke(VollmachtAuftrag auftrag);

  Future<VollmachtErgebnis> fuelleAus(VollmachtAuftrag auftrag);

  Future<VollmachtDrucker> ladeDrucker();

  Future<VollmachtVorschau> erstelleVorschau(VollmachtAuftrag auftrag);
}

@Injectable(as: VollmachtDatasource)
class ApiVollmachtDatasource implements VollmachtDatasource {
  final Dio _dio;

  ApiVollmachtDatasource(this._dio);

  /// Drucken wartet, bis Word den Auftrag an die Warteschlange übergeben hat:
  /// Dokument öffnen, drucken, schließen — beim ersten Mal samt Start von Word.
  /// Die knappe Vorgabe von drei Sekunden meldete sonst einen Fehlschlag,
  /// während das Papier schon aus dem Drucker kommt. Der Dienst selbst bricht
  /// nach 60 Sekunden ab (`PdfConversion:ConversionTimeoutSeconds`).
  static const Duration _druckTimeout = Duration(seconds: 90);

  /// Ausfüllen lädt und schreibt ein Word-Dokument — länger als ein Lesezugriff.
  static const Duration _ausfuellTimeout = Duration(seconds: 30);

  /// Die Vorschau füllt aus und wandelt über Word in PDF — kalt samt Start von
  /// Word. Wie beim Druck bricht der Dienst selbst nach 60 Sekunden ab.
  static const Duration _vorschauTimeout = Duration(seconds: 90);

  @override
  Future<VollmachtVorlagenStand> ladeVorlagen() async {
    final response = await _dio.get('/api/Vollmacht/vorlagen');
    return VollmachtVorlagenStand.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<Mandant?> ladeMandant(int id) async {
    try {
      final response = await _dio.get('/api/Mandanten/$id');
      return Mandant.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<VollmachtErgebnis> drucke(VollmachtAuftrag auftrag) =>
      _sende('/api/Vollmacht/drucken', auftrag, _druckTimeout);

  @override
  Future<VollmachtErgebnis> fuelleAus(VollmachtAuftrag auftrag) =>
      _sende('/api/Vollmacht/oeffnen', auftrag, _ausfuellTimeout);

  @override
  Future<VollmachtDrucker> ladeDrucker() async {
    final response = await _dio.get('/api/Vollmacht/drucker');
    return VollmachtDrucker.fromJson(response.data as Map<String, dynamic>);
  }

  /// Die Antwort kommt nicht ins Protokoll: Die Seite trägt Mandantendaten,
  /// und rund 140.000 Zeichen Base64 je Vorschau fluteten das Debug-Protokoll.
  @override
  Future<VollmachtVorschau> erstelleVorschau(VollmachtAuftrag auftrag) async =>
      VollmachtVorschau.fromJson(
        await _post(
          '/api/Vollmacht/vorschau',
          auftrag,
          _vorschauTimeout,
          ohneAntwortProtokoll: 'Seite der Vollmacht',
        ),
      );

  Future<VollmachtErgebnis> _sende(
    String pfad,
    VollmachtAuftrag auftrag,
    Duration timeout,
  ) async => VollmachtErgebnis.fromJson(await _post(pfad, auftrag, timeout));

  Future<Map<String, dynamic>> _post(
    String pfad,
    VollmachtAuftrag auftrag,
    Duration timeout, {
    String? ohneAntwortProtokoll,
  }) async {
    final response = await _dio.post(
      pfad,
      data: auftrag.toJson(),
      options: Options(
        contentType: Headers.jsonContentType,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        extra: {
          TextualLogInterceptor.keinAntwortProtokoll: ?ohneAntwortProtokoll,
        },
      ),
    );
    return response.data as Map<String, dynamic>;
  }
}
