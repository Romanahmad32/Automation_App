import 'dart:io';

/// Öffnet eine Datei im dafür eingerichteten Programm — liefert false, wenn
/// sich das nicht anstoßen ließ.
typedef DateiOeffnenFunktion = Future<bool> Function(String pfad);

/// Zeigt eine Datei im Explorer, markiert.
typedef DateiZeigenFunktion = Future<void> Function(String pfad);

/// **Der eine** Weg, aus der App eine Datei im Programm des Betriebssystems zu
/// öffnen — der Mail-Anhang vor dem Absenden (§4.7) und die Word-Vorlage im
/// Vorlageneditor (#104).
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
/// [oeffne] und [zeigeImOrdner] sind absichtlich **veränderliche** Felder und
/// keine festen Verweise — dieselbe Naht wie bei `VorlagenDateiwahl.waehle`:
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

  /// Der echte Weg. True, wenn sich das Öffnen anstoßen ließ. False heißt: Die
  /// Datei ist weg oder Windows kennt kein Programm dafür — beides gehört dem
  /// Anwalt gesagt, statt es zu verschlucken.
  static Future<bool> ueberWindowsShell(String pfad) async {
    if (!File(pfad).existsSync()) return false;

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

  /// Stellt beide Nähte auf den echten Weg zurück — der Weg zurück nach einem
  /// Test.
  static void zuruecksetzen() {
    oeffne = ueberWindowsShell;
    zeigeImOrdner = imExplorer;
  }
}
