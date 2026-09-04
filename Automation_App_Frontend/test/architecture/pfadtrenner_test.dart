import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Hält die Regex fest, mit der ein Pfad in seine Bestandteile zerfällt:
/// `[\\/]` — **zwei** Backslashes in der Zeichenklasse, nicht einer.
///
/// Anlass waren zwei Stellen, die `[\/]` schrieben (#32). Darin escapt der
/// Backslash den Schrägstrich, die Klasse enthält also nur noch `/` — und auf
/// Windows, wo jeder Pfad `C:\Akten\…` heißt, trennt sie gar nichts mehr.
/// `split` gibt dann den unveränderten Pfad zurück, `last` ist er selbst.
///
/// Das Tückische daran: Es ist kein Absturz und keine leere Anzeige, sondern
/// eine Zeile, die *fast* stimmt. Der Konfliktdialog der Ablage fragte
/// „Ersetzen oder beide behalten?" und zeigte dazu den vollen Pfad statt der
/// Dateinamen, die er zu zeigen versprach (seine Methode heißt `_dateinamen`);
/// die Rückfrage vor dem Neuerzeugen ebenso. Auf einem Unix-Rechner — und in
/// jedem Test mit `/`-Pfaden — sieht beides richtig aus.
///
/// Zweimal unabhängig entstanden heißt: ein drittes Mal ist eine Frage der
/// Zeit. Deshalb hier eine Regel und nicht zwei korrigierte Zeilen.
void main() {
  // Eine Zeichenklasse, die den Schrägstrich enthält und davor genau einen
  // Backslash — die kaputte Form. Die richtige (zwei Backslashes) und eine
  // Klasse ohne Schrägstrich gehen hier nicht durchs Netz.
  final kaputt = RegExp(r'\[\\/\]');

  test('Pfadtrenner-Regex escapt den Backslash, nicht den Schraegstrich', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final zeilen = datei.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        if (kaputt.hasMatch(zeilen[i])) {
          verstoesse.add('${relPfad(datei)}:${i + 1}: ${zeilen[i].trim()}');
        }
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Zeichenklassen trennen auf Windows keinen Pfad — der '
          'Backslash escapt dort den Schraegstrich, statt selbst in der Klasse '
          'zu stehen:\n  ${verstoesse.join('\n  ')}\n\n'
          'Richtig ist [\\\\/] mit zwei Backslashes. Wer wirklich nur nach '
          'Schraegstrichen trennen will, schreibt das ohne Zeichenklasse.',
    );
  });
}
