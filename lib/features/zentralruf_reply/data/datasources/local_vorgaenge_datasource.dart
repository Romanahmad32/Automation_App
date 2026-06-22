import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/offene_anfrage.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

/// Lokale Persistenz für den Zentralruf-Workflow (Req. 3.3 "speichern"):
/// die Vorgänge (gemeinsame Klammer über den Lebenszyklus) und — übergangsweise
/// noch — die alten Einzelschlüssel (zuletzt übernommene Vorgangsdaten + Liste
/// offener Anfragen), aus denen beim ersten Laden migriert wird. Gleiches
/// Dateischema wie die übrigen lokalen Speicher (JSON im Anwendungsordner,
/// atomar mit .bak-Sicherung).
abstract class LocalVorgaengeDatasource {
  /// Lädt die Vorgänge. Existiert noch kein `vorgaenge`-Schlüssel, wird einmalig
  /// aus dem alten Stand (offeneAnfragen + vorgangsdaten) migriert.
  Future<List<Vorgang>> loadVorgaenge();

  Future<void> saveVorgaenge(List<Vorgang> vorgaenge);

  Future<ZentralrufReplyData?> loadVorgangsdaten();

  Future<void> saveVorgangsdaten(ZentralrufReplyData? data);

  Future<List<OffeneAnfrage>> loadOffeneAnfragen();

  Future<void> saveOffeneAnfragen(List<OffeneAnfrage> anfragen);
}

class LocalVorgaengeDatasourceImpl implements LocalVorgaengeDatasource {
  final File _file;

  LocalVorgaengeDatasourceImpl._({required File file}) : _file = file;

  static Future<LocalVorgaengeDatasourceImpl> create(
      PathProviderWindows pathProviderWindows,) async {
    final String? supportPath = await pathProviderWindows
        .getApplicationSupportPath();
    if (supportPath == null) {
      throw const SettingsException('Kein Anwendungsordner gefunden');
    }
    return LocalVorgaengeDatasourceImpl._(
      file: File('$supportPath/zentralruf_vorgaenge.json'),
    );
  }

  @override
  Future<List<Vorgang>> loadVorgaenge() async {
    final store = await _load();
    final list = store['vorgaenge'];
    if (list is List) {
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>) Vorgang.fromJson(entry),
      ];
    }
    // Noch kein neues Schema → einmalige Migration aus dem Alt-Stand. Die
    // Alt-Schlüssel bleiben bewusst erhalten, bis saveVorgaenge das neue Schema
    // schreibt (gefahrloser Übergang, solange die alten Cubits noch laufen).
    return Vorgang.migriereAusLegacy(
      offeneAnfragen: await loadOffeneAnfragen(),
      letzteAntwort: await loadVorgangsdaten(),
    );
  }

  @override
  Future<void> saveVorgaenge(List<Vorgang> vorgaenge) async {
    final store = await _load();
    store['vorgaenge'] = [for (final vorgang in vorgaenge) vorgang.toJson()];
    await _writeAtomically(store);
  }

  @override
  Future<ZentralrufReplyData?> loadVorgangsdaten() async {
    final store = await _load();
    final json = store['vorgangsdaten'];
    return json is Map<String, dynamic>
        ? ZentralrufReplyData.fromJson(json)
        : null;
  }

  @override
  Future<void> saveVorgangsdaten(ZentralrufReplyData? data) async {
    final store = await _load();
    store['vorgangsdaten'] = data?.toJson();
    await _writeAtomically(store);
  }

  @override
  Future<List<OffeneAnfrage>> loadOffeneAnfragen() async {
    final store = await _load();
    final list = store['offeneAnfragen'];
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map<String, dynamic>) OffeneAnfrage.fromJson(entry),
    ];
  }

  @override
  Future<void> saveOffeneAnfragen(List<OffeneAnfrage> anfragen) async {
    final store = await _load();
    store['offeneAnfragen'] = [
      for (final anfrage in anfragen) anfrage.toJson(),
    ];
    await _writeAtomically(store);
  }

  Future<Map<String, dynamic>> _load() async {
    if (!await _file.exists()) {
      final backup = File('${_file.path}.bak');
      if (!await backup.exists()) {
        return {};
      }
      await backup.rename(_file.path);
    }

    try {
      final decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      // Beschädigte Datei: lieber mit leerem Stand weiterarbeiten, als den
      // Workflow zu blockieren — die Daten lassen sich neu übernehmen.
      return {};
    }
  }

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  Future<void> _writeAtomically(Map<String, dynamic> store) async {
    final tmp = File('${_file.path}.tmp');
    final backup = File('${_file.path}.bak');
    try {
      await tmp.writeAsString(_encoder.convert(store), flush: true);

      // Auf Windows schlägt File.rename fehl, wenn das Ziel bereits existiert.
      // Deshalb das Original erst zur Seite legen, dann tmp an seine Stelle.
      if (await _file.exists()) {
        if (await backup.exists()) await backup.delete();
        await _file.rename(backup.path);
      }
      try {
        await tmp.rename(_file.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(_file.path);
        rethrow;
      }
      try {
        if (await backup.exists()) await backup.delete();
      } catch (_) {}
    } catch (e) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}
