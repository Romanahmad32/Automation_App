import 'dart:io';

/// Startet ein Programm mit genau diesen Argumenten, ohne Shell.
typedef ProgrammStarten = Future<void> Function(
  String programm,
  List<String> argumente,
);

/// Öffnet „Lieber selbst herunterladen“ (#196) — direkt die Setup-Datei der
/// neuen Version im Standardbrowser, nicht die Release-Seite.
///
/// **Ohne Shell, über `rundll32 url.dll,FileProtocolHandler`** — derselbe Weg
/// wie bei `DateiOeffner`. Vorher lief es über `cmd /c start "" <adresse>`, und
/// die Adresse kommt aus einer API-Antwort: Ein `&`, `|`, `^` oder `%` darin
/// hätte `cmd` als Befehl gelesen. Ohne Shell ist sie nur ein Argument. Nicht
/// über url_launcher: `launchUrl` reagierte beim Öffnen erzeugter Dokumente
/// erst beim zweiten Klick (`wizard_step_review`).
///
/// Und geöffnet wird nur, was [istErlaubt] durchlässt: `https://github.com/…`.
/// Der Dienst gibt ohnehin nichts anderes heraus (`SetupAuswahl.FuerDenBrowser`);
/// hier steht dieselbe Regel noch einmal, weil das Frontend die Adresse an
/// Windows weiterreicht und nicht wissen kann, wer ihm gerade antwortet.
///
/// [starte] ist absichtlich ein **veränderliches** Feld — dieselbe Naht wie
/// bei `DateiOeffner.oeffne`: Ein Widget-Test darf keinen Browser starten.
/// Der Test setzt das Feld und stellt es über [zuruecksetzen] zurück.
abstract final class BrowserOeffner {
  /// Startet das Programm — im Test ersetzbar (siehe oben).
  static ProgrammStarten starte = ohneShell;

  /// Nur Zeichen, die in einer Adresse vorkommen dürfen (RFC 3986, mit `%` für
  /// kodierte): kein Leerzeichen, kein Anführungszeichen, kein `^`, `|`, `<`,
  /// `>`, `\`. Ohne Shell ist keins davon gefährlich, aber in einer Adresse
  /// von GitHub kommt auch keins vor — wer so etwas schickt, ist nicht GitHub.
  static final RegExp _adresszeichen = RegExp(
    r"^[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+$",
  );

  /// Öffnet [adresse] im Standardbrowser. `false`, wenn sie nicht erlaubt ist
  /// ([istErlaubt]) oder sich nichts starten ließ — dann ist nichts geöffnet.
  static Future<bool> oeffne(String adresse) async {
    if (!istErlaubt(adresse)) return false;
    try {
      await starte('rundll32', ['url.dll,FileProtocolHandler', adresse]);
      return true;
    } on ProcessException {
      return false;
    }
  }

  /// Nur `https`, nur der Host `github.com`, ohne Anmeldedaten und ohne
  /// fremden Port.
  static bool istErlaubt(String adresse) {
    if (!_adresszeichen.hasMatch(adresse)) return false;
    final uri = Uri.tryParse(adresse);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443);
  }

  /// Der echte Weg: `Process.start` ohne `runInShell`.
  static Future<void> ohneShell(String programm, List<String> argumente) async {
    await Process.start(programm, argumente);
  }

  /// Stellt die Naht auf den echten Weg zurück — nach einem Test.
  static void zuruecksetzen() => starte = ohneShell;
}
