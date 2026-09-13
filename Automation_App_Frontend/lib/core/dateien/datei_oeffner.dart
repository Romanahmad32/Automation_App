import 'dart:io';

/// Öffnet eine Datei im dafür eingerichteten Programm — liefert false, wenn
/// sich das nicht anstoßen ließ.
typedef DateiOeffnenFunktion = Future<bool> Function(String pfad);

/// Zeigt eine Datei im Explorer, markiert.
typedef DateiZeigenFunktion = Future<void> Function(String pfad);

/// **Der eine** Weg, aus der App eine Datei im Programm des Betriebssystems zu
/// öffnen — der Mail-Anhang vor dem Absenden (§4.7) und die Word-Vorlage im
/// Vorlageneditor (#104) — und einen Ordner im Explorer: die Akte und ihre
/// Fälle an der Mandantenkarte (#132).
///
/// Aus dem Feature `email_versand` nach `core/` gehoben: Die Mechanik hat
/// nichts mit Mailversand zu tun, und die zweite Aufrufstelle im
/// Vorlageneditor hätte sich sonst entweder quer über eine fremde
/// `presentation`-Schicht bedient oder eine zweite Fassung danebengestellt.
///
/// **Direkt über `rundll32` statt `cmd /c start`**: Der Pfad geht dann nicht
/// durch die Shell, und ein `&` im Ordnernamen (Kanzleien heißen gern „Müller
/// & Partner") zerlegt den Aufruf nicht. Und nicht über `url_launcher`:
/// `launchUrl` öffnete die Datei erst beim zweiten Klick (siehe
/// `wizard_step_review.dart`, das denselben Weg noch von Hand geht).
///
/// [oeffne], [zeigeImOrdner] und [oeffneOrdner] sind absichtlich
/// **veränderliche** Felder und keine festen Verweise — dieselbe Naht wie bei `VorlagenDateiwahl.waehle`:
/// Ein Widget-Test darf keinen Prozess starten, und die aufrufenden Widgets
/// können die Funktion nicht als Parameter nehmen, ohne sie durch drei
/// Bausteine hindurchzureichen. Der Test setzt das Feld und stellt es über
/// [zuruecksetzen] in einem `addTearDown` zurück.
class DateiOeffner {
  const DateiOeffner._();

  /// Öffnet die Datei — im Test ersetzbar (siehe oben).
  static DateiOeffnenFunktion oeffne = ueberWindowsShell;

  /// Zeigt die Datei im Explorer — im Test ersetzbar (siehe oben).
  static DateiZeigenFunktion zeigeImOrdner = imExplorer;

  /// Öffnet einen Ordner im Explorer — im Test ersetzbar (siehe oben).
  static DateiOeffnenFunktion oeffneOrdner = ordnerImExplorer;

  /// Der echte Weg. True, wenn sich das Öffnen anstoßen ließ. False heißt: Die
  /// Datei ist weg oder Windows kennt kein Programm dafür — beides gehört dem
  /// Anwalt gesagt, statt es zu verschlucken.
  static Future<bool> ueberWindowsShell(String pfad) async {
    // Asynchron geprüft — Begründung an [ordnerImExplorer].
    if (!await File(pfad).exists()) return false;

    try {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', pfad]);
      return true;
    } on ProcessException {
      return false;
    }
  }

  /// Zeigt die Datei im Explorer, markiert. Der Weg für alles, was sich nicht
  /// öffnen lässt — und für „wo liegt das eigentlich?".
  static Future<void> imExplorer(String pfad) async {
    try {
      await Process.start('explorer', ['/select,', pfad]);
    } on ProcessException {
      // Ohne Explorer ist ohnehin nichts zu machen.
    }
  }

  /// Öffnet den Ordner selbst im Explorer. True, wenn sich das anstoßen ließ;
  /// false heißt fast immer: Der Ordner ist umbenannt oder verschoben.
  ///
  /// Nicht über [ueberWindowsShell]: Das prüft, ob eine **Datei** da ist, und
  /// das ist für einen Ordner immer falsch. Und nicht über [imExplorer]:
  /// `/select,` öffnet den **übergeordneten** Ordner und markiert den gemeinten
  /// darin — wer die Akte öffnen will, stünde dann im Stammordner zwischen
  /// 4000 anderen.
  ///
  /// **Asynchron geprüft, nie `existsSync`:** Die Akten liegen gern auf einem
  /// Netzlaufwerk, und ein weggebrochenes hält die Abfrage bis zum
  /// SMB-Timeout fest — auf dem UI-Isolat eine eingefrorene App ohne jede
  /// Rückmeldung.
  ///
  /// **Über `rundll32` und nicht `explorer <pfad>`:** Der Explorer zerlegt
  /// seine Befehlszeile an Kommas, und Dart setzt ein Argument nur bei
  /// Leerzeichen, Tab oder Anführungszeichen in Anführungszeichen. „Müller,Hans"
  /// öffnete dann die Dokumente — und die Funktion meldete Erfolg.
  /// `rundll32` wertet nur sein erstes Argument aus und reicht den Rest an
  /// `FileProtocolHandler` weiter, das einen Ordner im Explorer öffnet (am
  /// 13.09.2026 mit „Müller,Hans" und „Müller, Hans" nachgeprüft). Wie bei
  /// [ueberWindowsShell] geht der Pfad nicht durch eine Shell, ein `&` im
  /// Ordnernamen zerlegt den Aufruf also auch nicht.
  static Future<bool> ordnerImExplorer(String pfad) async {
    if (!await Directory(pfad).exists()) return false;

    try {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', pfad]);
      return true;
    } on ProcessException {
      return false;
    }
  }

  /// Stellt alle Nähte auf den echten Weg zurück — der Weg zurück nach einem
  /// Test.
  static void zuruecksetzen() {
    oeffne = ueberWindowsShell;
    zeigeImOrdner = imExplorer;
    oeffneOrdner = ordnerImExplorer;
  }
}
