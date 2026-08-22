import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt die Längenobergrenze für handgeschriebene Dart-Dateien aus
/// CLAUDE.md: Richtwert **250 Zeilen**, in Ausnahmefällen maximal **300**.
///
/// Gezählt werden rohe Zeilen (inkl. Leerzeilen, Kommentaren und Importen),
/// entsprechend der wörtlichen Regel. Generierte Dateien sind ausgenommen
/// (siehe [generierteEndungen]).
void main() {
  const richtwert = 250;
  const hartesLimit = 300;

  test(
    'keine handgeschriebene Dart-Datei überschreitet $hartesLimit Zeilen',
    () {
      final verstoesse = <String>[];
      for (final datei in dartQuelldateien('lib')) {
        final zeilen = datei.readAsLinesSync().length;
        if (zeilen > hartesLimit) {
          verstoesse.add('${relPfad(datei)} ($zeilen Zeilen)');
        }
      }
      verstoesse.sort();

      expect(
        verstoesse,
        isEmpty,
        reason:
            'Folgende Dateien überschreiten das harte Limit von '
            '$hartesLimit Zeilen (Richtwert: $richtwert) und müssen in '
            'kleinere, eigenständige Widgets/Klassen aufgeteilt werden:\n  '
            '${verstoesse.join('\n  ')}',
      );
    },
  );
}
