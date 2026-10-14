import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Der HTTP-Vertrag der Aktualisierung (`api/Aktualisierung`, #196), roh:
/// wirft bei einem Fehler die [DioException] weiter. Die Übersetzung in
/// `Either<Failure, T>` liegt in `AktualisierungRepositoryImpl`.
abstract class AktualisierungDatasource {
  Future<AktualisierungsStand> stand();

  Future<AktualisierungsStand> pruefen();

  Future<AktualisierungsStand> herunterladen();

  Future<AktualisierungsStand> abbrechen();

  Future<AktualisierungsStand> installieren();

  Future<void> ergebnisQuittieren();
}

@Injectable(as: AktualisierungDatasource)
class ApiAktualisierungDatasource implements AktualisierungDatasource {
  final Dio _dio;

  ApiAktualisierungDatasource(this._dio);

  /// Der Dienst fragt GitHub mit höchstens zehn Sekunden Frist
  /// (`AktualisierungOptions.PruefZeitlimit`); die 3-Sekunden-Vorgabe des
  /// Dio schnitte die Antwort vorher ab.
  static const Duration pruefFrist = Duration(seconds: 20);

  /// Vor dem Start prüft der Dienst die Setup-Datei (~85 MB) noch einmal.
  static const Duration installierFrist = Duration(seconds: 60);

  /// Der Abbruch wartet, bis der Download seine Teildatei weggeräumt hat.
  static const Duration abbruchFrist = Duration(seconds: 30);

  @override
  Future<AktualisierungsStand> stand() async =>
      _lies(await _dio.get<Map<String, dynamic>>('/api/Aktualisierung'));

  @override
  Future<AktualisierungsStand> pruefen() async => _lies(
    await _dio.post<Map<String, dynamic>>(
      '/api/Aktualisierung/pruefen',
      options: Options(receiveTimeout: pruefFrist),
    ),
  );

  @override
  Future<AktualisierungsStand> herunterladen() async => _lies(
    await _dio.post<Map<String, dynamic>>('/api/Aktualisierung/herunterladen'),
  );

  @override
  Future<AktualisierungsStand> abbrechen() async => _lies(
    await _dio.post<Map<String, dynamic>>(
      '/api/Aktualisierung/abbrechen',
      options: Options(receiveTimeout: abbruchFrist),
    ),
  );

  @override
  Future<AktualisierungsStand> installieren() async => _lies(
    await _dio.post<Map<String, dynamic>>(
      '/api/Aktualisierung/installieren',
      options: Options(receiveTimeout: installierFrist),
    ),
  );

  @override
  Future<void> ergebnisQuittieren() =>
      _dio.post<void>('/api/Aktualisierung/ergebnis-quittieren');

  /// Jede Antwort trägt den ganzen Stand. Fehlt er, hat etwas anderes als
  /// dieser Dienst geantwortet — das soll auffallen, nicht still `null` sein.
  AktualisierungsStand _lies(Response<Map<String, dynamic>> antwort) {
    final daten = antwort.data;
    if (daten == null) {
      throw StateError('Der Dienst hat keinen Aktualisierungsstand geliefert.');
    }
    return AktualisierungsStand.fromJson(daten);
  }
}
