import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_historie_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Die übernommene Registerhistorie über das Backend
/// (`GET /api/RegisterHistorie/stand`, `GET|PUT /api/RegisterHistorie/{id}`).
///
/// Die Antwort des `PUT` — die gespeicherte Zeile — wird bewusst verworfen:
/// Die Ansicht lädt danach ohnehin alle Zeilen neu, weil eine Berichtigung
/// auch die Befunde der Zeile und damit den Stand ihres Jahrgangs verändert.
/// Nur die geänderte Zeile einzusetzen hieße, den Stand daneben veralten zu
/// lassen.
@Injectable(as: RegisterHistorieRepository)
class ApiRegisterHistorieDatasource implements RegisterHistorieRepository {
  final Dio _dio;

  ApiRegisterHistorieDatasource(this._dio);

  @override
  Future<RegisterHistorieStand> ladeStand() async {
    final response = await _dio.get('/api/RegisterHistorie/stand');
    return RegisterHistorieStand.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<RegisterHistorieZeile> lade(int id) async {
    final response = await _dio.get('/api/RegisterHistorie/$id');
    return RegisterHistorieZeile.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> aendere(int id, RegisterHistorieAenderung aenderung) async {
    await _dio.put('/api/RegisterHistorie/$id', data: aenderung.toJson());
  }

  @override
  Future<void> loesche(int id) async {
    try {
      await _dio.delete('/api/RegisterHistorie/$id');
    } on DioException catch (e) {
      // Kein Treffer erfüllt denselben No-op-Vertrag wie beim Vorgang: Ein
      // wiederholter Löschversuch, der doch schon durchging, ist kein Fehler.
      if (e.response?.statusCode != 404) rethrow;
    }
  }
}
