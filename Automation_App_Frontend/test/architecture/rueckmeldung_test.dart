import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt, dass flüchtige Rückmeldungen an den Anwalt ausschließlich über
/// den Baustein `Rueckmeldung` laufen (`lib/core/general_widgets/rueckmeldung/`)
/// und nirgendwo sonst direkt über `ScaffoldMessenger`/`SnackBar` (Issue #56,
/// 04.09.2026).
///
/// Hintergrund: Vor dem Baustein rief jede Stelle, die kurz etwas melden
/// wollte, `ScaffoldMessenger.of(context).showSnackBar(...)` unmittelbar auf.
/// Zwei Eigenheiten von `SnackBar` passten dabei nicht zu dieser App. Erstens
/// liegt sie unten am Bildschirmrand — genau dort, wo der nächste Knopf sitzt,
/// den der Anwalt als Nächstes drücken will (etwa „Speichern" oder „Weiter");
/// die Meldung verdeckte ihn. Zweitens hängt sie am `Scaffold` der Seite, die
/// sie auslöst — und die App hat davon nur **eines**, in der Shell. Schloss
/// eine Aktion zuerst einen Dialog und meldete danach per Snackbar, lag die
/// Meldung **hinter** der schon geschlossenen Dialogbarriere: unsichtbar oder
/// gleich mit dem Dialog entsorgt.
///
/// `Rueckmeldung` schreibt stattdessen in das Wurzel-Overlay, oberhalb jeder
/// Dialogbarriere und oben rechts gestapelt statt unten liegend. Ein zweiter
/// Weg für dieselbe Aufgabe wäre nur eine Falle für die nächste Änderung
/// gewesen — deshalb sind alle 52 vormaligen Snackbar-Aufrufstellen in
/// `lib/features/` bereits auf `Rueckmeldung` umgestellt; dieser Test hält es
/// dabei.
void main() {
  // Einzige zulässige Stelle für die vier Begriffe: der Baustein selbst. Er
  // erklärt seine Existenz in Doc-Kommentaren mit genau diesen Wörtern
  // ("kein ScaffoldMessenger mehr nötig") — deshalb zählen nur Code-Zeilen,
  // keine Kommentarzeilen (`//` oder `///`).
  const erlaubtesVerzeichnis = 'lib/core/general_widgets/rueckmeldung/';

  // Namentliche Ausnahmen außerhalb des Bausteins. **Bleibt leer** — jede
  // Stelle, die eine flüchtige Meldung braucht, hat mit `Rueckmeldung` einen
  // Weg, der weder Dialogbarriere noch Schaltflächen im Weg steht (Vorbild:
  // die `altlasten`-Map in file_length_test.dart). Ein neuer Eintrag hier
  // wäre keine Ausnahme, sondern die alte Falle unter neuem Namen.
  const ausnahmen = <String>{};

  const verboteneBegriffe = [
    'ScaffoldMessenger',
    'showSnackBar(',
    'SnackBar(',
    'SnackBarAction(',
  ];

  test('keine Datei ausserhalb des Rueckmeldung-Bausteins verwendet '
      'ScaffoldMessenger/SnackBar', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final pfad = relPfad(datei);
      if (pfad.startsWith(erlaubtesVerzeichnis)) continue;
      if (ausnahmen.contains(pfad)) continue;

      for (final zeile in datei.readAsLinesSync()) {
        if (zeile.trimLeft().startsWith('//')) continue;

        for (final begriff in verboteneBegriffe) {
          if (zeile.contains(begriff)) {
            verstoesse.add('$pfad: "$begriff"');
            break;
          }
        }
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Flüchtige Meldungen laufen ausschließlich über Rueckmeldung '
          '(lib/core/general_widgets/rueckmeldung/), nie direkt über '
          'ScaffoldMessenger/SnackBar (Issue #56):\n  '
          '${verstoesse.join('\n  ')}',
    );
  });
}
