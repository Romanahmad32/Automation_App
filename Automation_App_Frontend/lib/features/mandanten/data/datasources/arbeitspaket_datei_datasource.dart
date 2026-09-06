import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:injectable/injectable.dart';

/// Schreibt ein [Arbeitspaket] als JSON-Datei auf die Platte — das Gegenstück
/// zu `ImportDateiDatasource`, die die Antwort des Agenten wieder einliest.
///
/// Der Speichern-Dialog gehört **nicht** hierher: `FilePicker.saveFile` ist
/// Oberfläche und fragt den Anwalt, wohin. Hier kommt ein fertiger Pfad an —
/// nur so bleibt das Schreiben ohne laufende Oberfläche prüfbar.
abstract class ArbeitspaketDateiDatasource {
  /// Schreibt [paket] nach [pfad]. Eine vorhandene Datei wird ersetzt: den
  /// Namen hat der Anwalt im Dialog eben bestätigt.
  Future<void> schreibe({required Arbeitspaket paket, required String pfad});
}

@Injectable(as: ArbeitspaketDateiDatasource)
class FilesystemArbeitspaketDateiDatasource
    implements ArbeitspaketDateiDatasource {
  @override
  Future<void> schreibe({
    required Arbeitspaket paket,
    required String pfad,
  }) async {
    final datei = File(pfad);
    try {
      await datei.parent.create(recursive: true);
      // Die Datei trägt deutsche Ordner- und Mandantennamen und wird von einem
      // fremden Werkzeug gelesen. Ohne Angabe träfe das Schreiben unter Windows
      // die Codepage der Konsole und machte aus „Bußgeldsache" Zeichensalat.
      await datei.writeAsString(jsonEncode(paket.toJson()), encoding: utf8);
    } on FileSystemException catch (e) {
      throw MandantException(
        'Die Datei „$pfad" konnte nicht geschrieben werden: '
        '${e.osError?.message ?? e.message}',
      );
    }
  }
}
