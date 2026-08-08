import 'dart:async';
import 'dart:io';

/// Öffnet die Release-Seite im Standardbrowser.
///
/// Über den Windows-Shell-Befehl `start` statt url_launcher — dieselbe
/// Entscheidung wie beim Öffnen erzeugter Dokumente (`wizard_step_review`),
/// wo `launchUrl` erst beim zweiten Klick reagierte.
void releaseSeiteOeffnen(String adresse) {
  unawaited(
    Process.run('cmd', ['/c', 'start', '', adresse], runInShell: false),
  );
}
