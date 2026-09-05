import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Zugriff auf die Kanzlei-Einstellungen über das Backend (`api/Settings`).
/// Löst den früheren lokalen JSON-Speicher (kanzlei_settings.json) ab; die
/// SQLite-Datenbank im Backend ist jetzt die alleinige Quelle der Wahrheit.
abstract class KanzleiSettingsDatasource {
  Future<KanzleiSettings> loadSettings();

  Future<KanzleiSettings> saveSettings(KanzleiSettings settings);

  /// Zählt die laufende Auftragsnummer atomar im Backend hoch (§7.1) und
  /// gibt den gespeicherten Stand zurück.
  Future<KanzleiSettings> erhoeheAuftragsnummer();

  /// Wie es um die fünf Ordner steht — je Feld die Speicherform, der wirksame
  /// Ordner und der Grund dafür. Eigene Abfrage und kein Teil von
  /// [loadSettings], weil sie auf die Platte sieht und die Umgebung auswertet:
  /// Das gehört nicht in jeden Aufruf, der bloß die Kanzleidaten braucht.
  Future<List<OrdnerZustand>> ladeOrdnerZustand();
}

@Injectable(as: KanzleiSettingsDatasource)
class ApiKanzleiSettingsDatasource implements KanzleiSettingsDatasource {
  final Dio _dio;

  ApiKanzleiSettingsDatasource(this._dio);

  @override
  Future<KanzleiSettings> loadSettings() async {
    final response = await _dio.get('/api/Settings');
    return KanzleiSettings.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<KanzleiSettings> saveSettings(KanzleiSettings settings) async {
    final response = await _dio.put(
      '/api/Settings',
      data: settings.toJson(),
      options: Options(contentType: Headers.jsonContentType),
    );
    return KanzleiSettings.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<KanzleiSettings> erhoeheAuftragsnummer() async {
    final response = await _dio.post('/api/Settings/auftragsnummer/erhoehe');
    return KanzleiSettings.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<OrdnerZustand>> ladeOrdnerZustand() async {
    final response = await _dio.get('/api/Settings/ordner');
    return (response.data as List)
        .map(
          (eintrag) => OrdnerZustand.fromJson(eintrag as Map<String, dynamic>),
        )
        .toList();
  }
}
