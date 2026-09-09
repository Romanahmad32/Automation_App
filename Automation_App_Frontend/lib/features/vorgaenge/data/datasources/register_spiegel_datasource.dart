import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Der Register-Spiegel über das Backend (`api/Vorgaenge/register`).
///
/// Keine eigene Repository-Umsetzung dazwischen: Es gibt nichts zu übersetzen,
/// die Antwort *ist* der Stand.
///
/// Beide Wege antworten immer mit 200 und einem Stand. Ein gesperrter
/// Ablageordner ist kein Serverfehler, sondern eine Lage, die die Oberfläche in
/// einem Satz erklärt — er steht in `fehler`, nicht in einem Statuscode.
///
/// Was hier als Ausnahme herauskommt, ist deshalb immer ein Fehlschlag der
/// Leitung — und der wird **hier** in einen Satz übersetzt. Weiter oben landete
/// sonst der Ausnahmetext von Dio wortwörtlich in der Meldung an den Anwalt
/// („DioException [connection error] …"), und der sagt ihm nichts.
@Injectable(as: RegisterSpiegelRepository)
class ApiRegisterSpiegelDatasource implements RegisterSpiegelRepository {
  final Dio _dio;

  ApiRegisterSpiegelDatasource(this._dio);

  /// Schreiben heißt: Word-Datei bauen, Word starten, in PDF wandeln, beides
  /// umziehen. Der Vorgabewert von drei Sekunden (`network_module.dart`) ist
  /// dafür keine Zeit — allein der Kaltstart von Word braucht rund anderthalb.
  /// Lief die Uhr ab, meldete der Bildschirm eine Zeitüberschreitung, während
  /// der Dienst in Ruhe zu Ende schrieb: die eine Meldung, die den Anwalt zu
  /// einem zweiten Druck verleitet, der dieselbe Arbeit noch einmal anstößt.
  ///
  /// Zwei Minuten sind die Obergrenze für den Fall, dass Word gar nicht
  /// antwortet — nicht die erwartete Dauer. Dieselbe Vorsorge trifft
  /// `WordAutomationDatasource` (60 s) und `ZentralrufDatasource` (3 min).
  static const Duration _schreibdauer = Duration(minutes: 2);

  @override
  Future<RegisterSpiegelErgebnis> exportiere({bool erzwingen = true}) => _hole(
    'Das Register konnte nicht geschrieben werden',
    () => _dio.post(
      '/api/Vorgaenge/register/export',
      queryParameters: {'erzwingen': erzwingen},
      options: Options(receiveTimeout: _schreibdauer),
    ),
  );

  @override
  Future<RegisterSpiegelErgebnis> ladeStand() => _hole(
    'Der Stand des Registers konnte nicht geladen werden',
    () => _dio.get('/api/Vorgaenge/register/stand'),
  );

  Future<RegisterSpiegelErgebnis> _hole(
    String was,
    Future<Response<dynamic>> Function() abruf,
  ) async {
    try {
      final response = await abruf();
      return RegisterSpiegelErgebnis.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw RegisterException(
        backendFehlertext(e) ?? dienstOhneAntwort(e, was),
      );
    }
  }
}
