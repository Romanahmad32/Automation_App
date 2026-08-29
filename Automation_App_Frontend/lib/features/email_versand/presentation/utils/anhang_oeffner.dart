import 'dart:io';

/// Öffnet einen Anhang im dafür eingerichteten Programm (§4.7).
///
/// Damit lässt sich vor dem Absenden nachsehen, ob wirklich das richtige
/// Dokument dranhängt — bei Dateinamen wie „Anspruchsschreiben (2).pdf" ist das
/// keine akademische Frage.
///
/// Direkt über `rundll32` statt `cmd /c start`: Der Pfad geht dann nicht durch
/// die Shell, und ein `&` im Ordnernamen (Kanzleien heißen gern „Müller &
/// Partner") zerlegt den Aufruf nicht.
class AnhangOeffner {
  const AnhangOeffner._();

  /// True, wenn sich das Öffnen anstoßen ließ. False heißt: Die Datei ist weg
  /// oder Windows kennt kein Programm dafür — beides gehört dem Anwalt gesagt,
  /// statt es zu verschlucken.
  static Future<bool> oeffne(String pfad) async {
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
  static Future<void> zeigeImOrdner(String pfad) async {
    try {
      await Process.start('explorer', ['/select,', pfad]);
    } on ProcessException {
      // Ohne Explorer ist ohnehin nichts zu machen.
    }
  }
}
