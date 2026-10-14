import 'dart:io';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart' show ServicesBinding;

/// Beendet die Anwendung **auf demselben Weg wie das Schließen des Fensters**
/// — gebraucht nach „Jetzt neu starten“ (#196), wenn der Installer schon
/// läuft und darauf wartet, dass Anwendung und Dienst fort sind.
///
/// Der Weg beim Schließen über das X: Windows schickt `WM_CLOSE`, das Fenster
/// geht zu, `Win32Window` ruft `PostQuitMessage(0)`, die Nachrichtenschleife in
/// `windows/runner/main.cpp` endet und mit ihr der Prozess. Der Dienst merkt
/// das über seinen `ParentProcessWatchdog` (er bekam beim Start `--parent-pid`,
/// siehe `BackendLauncher`) und fährt **geordnet** herunter: Er schreibt bis
/// zu 60 s die Sicherung und gibt seine Word-Instanz frei. Abgeschossen wird
/// hier nichts — der Dienst nicht und Word schon gar nicht. Hat die App beim
/// Start einen schon laufenden Dienst übernommen (ohne `--parent-pid`), fährt
/// der nach dem Installer-Start einige Sekunden später von selbst auf
/// demselben Weg herunter (`GeordnetesHerunterfahren` im Dienst).
///
/// `exitApplication(required)` bittet die Engine um genau dieses Ende: Sie
/// ruft `PostQuitMessage`, die Schleife endet wie beim Schließen, und die
/// Engine räumt vorher ordentlich auf (anders als `dart:io` `exit`, das den
/// Prozess sofort beendet). `required` statt `cancelable`, weil nichts das
/// Ende mehr aufhalten darf: Der Installer läuft schon, und der Anwalt wurde
/// vorher gebeten, offene Eingaben zu speichern.
abstract final class AnwendungBeenden {
  static Future<void> regulaer() async {
    final antwort = await ServicesBinding.instance.exitApplication(
      AppExitType.required,
    );
    // Kennt die Engine den Aufruf nicht (dann kommt `cancel`), endet der
    // Prozess eben direkt — für den Dienst ist das dasselbe Signal: Der
    // Elternprozess ist fort.
    if (antwort == AppExitResponse.cancel) exit(0);
  }
}
