import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:injectable/injectable.dart';

/// Liest eine Importdatei von der Platte. Eigene Datasource, weil das Lesen
/// einer vom Anwender ausgewählten Datei genauso eine Herkunft ist wie der
/// Akten-Scan — und `dart:io` damit unterhalb der Präsentation bleibt.
///
/// Es gibt **zwei** Importe mit demselben Ablauf (Mandanten §5.1/§6.1,
/// Registerhistorie §6.2) und derselben Herkunft: eine maschinell erzeugte
/// JSON-Datei auf dem Kanzleirechner. Deshalb liegt das rohe Lesen — Datei da?
/// UTF-8? gültiges JSON-Objekt? — in [liesJson] und wird geteilt; nur das
/// Deuten der Felder gehört dem jeweiligen Feature. Eine zweite Fassung davon
/// liefe beim ersten Sonderfall auseinander (Windows-Codepage, BOM, leere
/// Datei), und der zweite Import bekäme die Berichtigung des ersten nie.
abstract class ImportDateiDatasource {
  Future<MandantenImportDatei> lies(String pfad);

  /// Dieselbe Datei als rohes JSON-Objekt — für jeden Import, der die Felder
  /// selbst deutet.
  Future<Map<String, dynamic>> liesJson(String pfad);
}

@Injectable(as: ImportDateiDatasource)
class FilesystemImportDateiDatasource implements ImportDateiDatasource {
  @override
  Future<MandantenImportDatei> lies(String pfad) async =>
      MandantenImportDatei.fromJson(await liesJson(pfad));

  @override
  Future<Map<String, dynamic>> liesJson(String pfad) async {
    final datei = File(pfad);
    if (!await datei.exists()) {
      throw MandantException('Die Datei „$pfad" gibt es nicht.');
    }

    // Die Datei ist maschinell erzeugt und trägt deutsche Namen — sie ohne
    // Angabe zu lesen träfe unter Windows die Codepage der Konsole und machte
    // aus „Bußgeldsache" stillen Zeichensalat.
    final text = await datei.readAsString(encoding: utf8);

    final Object? roh;
    try {
      roh = jsonDecode(text);
    } on FormatException catch (e) {
      throw MandantException('Die Datei ist kein gültiges JSON: ${e.message}');
    }

    if (roh is! Map<String, dynamic>) {
      throw MandantException(
        'Erwartet wird ein JSON-Objekt mit einem Feld „version" — siehe '
        'docs/MANDANTEN_IMPORT.md bzw. docs/REGISTER_IMPORT.md.',
      );
    }

    return roh;
  }
}
