import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:injectable/injectable.dart';

/// Schreibt die Paketdatei auf die Platte — das Gegenstück zur lesenden
/// `ImportDateiDatasource`. Eigene Datasource aus demselben Grund: das
/// Schreiben einer vom Anwalt gewählten Datei ist eine Herkunft wie der
/// Akten-Scan, und `dart:io` bleibt damit unterhalb der Präsentation.
abstract class ArbeitspaketDateiDatasource {
  Future<void> schreibe(String pfad, String inhalt);
}

@Injectable(as: ArbeitspaketDateiDatasource)
class FilesystemArbeitspaketDateiDatasource
    implements ArbeitspaketDateiDatasource {
  @override
  Future<void> schreibe(String pfad, String inhalt) async {
    final datei = File(pfad);
    try {
      await datei.parent.create(recursive: true);
      // Ausdrücklich utf8: die Datei trägt deutsche Ordner- und Mandanten-
      // namen und wird von einem Programm gelesen, das UTF-8 erwartet. Ohne
      // Angabe träfe sie unter Windows die Codepage der Konsole und machte aus
      // „Bußgeldsache" stillen Zeichensalat.
      await datei.writeAsString(inhalt, encoding: utf8, flush: true);
    } on FileSystemException catch (e) {
      throw MandantException(
        'Die Paketdatei „$pfad" konnte nicht geschrieben werden: '
        '${e.osError?.message ?? e.message}',
      );
    }
  }
}
