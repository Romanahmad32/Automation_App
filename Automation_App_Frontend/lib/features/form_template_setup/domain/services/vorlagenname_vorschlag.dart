/// Schlägt aus dem Dateinamen einer Word-Datei einen Vorlagennamen vor
/// (#104, §5.3) — der erste Schritt im Ablauf „Datei zuerst".
///
/// Bis hierher tippte der Anwalt den Namen, bevor überhaupt eine Datei
/// verknüpft war: Er stand vor einem leeren Feld und musste sich einen Namen
/// ausdenken für etwas, das er gleich danach auswählt. Die Kanzleidateien
/// heißen `VORLAGE <Sache> ohne Auflistung.docx` — der Name steht also längst
/// da, er muss nur abgeschrieben werden.
///
/// **Beide Word-Dateien einer Vorlage ergeben denselben Vorschlag.** Das ist
/// der Grund für die Suffixliste: `VORLAGE Anspruchsschreiben ohne
/// Auflistung.docx` und `VORLAGE Anspruchsschreiben-SA.docx` gehören zu
/// derselben Vorlage, und welche der beiden der Anwalt zuerst wählt, darf den
/// Namen nicht bestimmen. Die beiden Dateien sind gleichwertig.
///
/// Vorgeschlagen, nicht gesetzt (§1.3): Der Aufrufer schreibt den Vorschlag nur
/// in ein leeres Namensfeld und sagt dazu, woher er stammt
/// (`VorlagenBearbeitung.nameVorschlagen`).
class VorlagennameVorschlag {
  const VorlagennameVorschlag._();

  /// Wortanfänge, die zur Ablage gehören und nicht zum Namen. Verglichen wird
  /// ohne Groß-/Kleinschreibung und nur als **ganzes Wort** — eine Vorlage
  /// „Vorlagenwechsel" verlöre sonst ihre ersten sieben Buchstaben.
  static const List<String> praefixe = ['vorlage'];

  /// Wortenden, die sagen, **welche** der beiden Dateien es ist — nie, worum
  /// es in der Vorlage geht. Alle mit führendem Leerzeichen: `-SA` und `_SA`
  /// sind zu diesem Zeitpunkt schon zu ` SA` geworden.
  static const List<String> suffixe = [
    ' ohne auflistung',
    ' mit auflistung',
    ' ohne schadensaufstellung',
    ' mit schadensaufstellung',
    ' sa',
  ];

  /// Der Dateiname mit Endung (`C:\Vorlagen\HGN.docx` → `HGN.docx`) — für den
  /// Hinweis „aus HGN.docx vorgeschlagen" unter dem Namensfeld. Beide Trenner,
  /// weil der Pfad aus dem Dateidialog kommt und Tests ihn mit `/` schreiben.
  static String dateiname(String pfad) => pfad.split(RegExp(r'[\\/]')).last;

  /// Der Namensvorschlag zu [pfad] — leer heißt: kein Vorschlag.
  ///
  /// Der Reihe nach: Dateiname ohne Endung, `_` und `-` zu Leerzeichen,
  /// mehrfache Leerzeichen zusammengezogen, Präfixe und Suffixe abgeschnitten.
  /// Bleibt nichts übrig (`VORLAGE.docx`, `_.docx`), ist die Antwort der leere
  /// String: Lieber kein Vorschlag als ein sinnloser, den der Anwalt erst
  /// wieder wegräumen muss.
  static String ausPfad(String pfad) {
    var name = dateiname(pfad);
    final punkt = name.lastIndexOf('.');
    // > 0, nicht >= 0: `.docx` ohne Namen davor ist kein Name mit Endung.
    if (punkt > 0) name = name.substring(0, punkt);
    name = name.replaceAll(RegExp(r'[_-]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _ohneSuffix(_ohnePraefix(name)).trim();
  }

  static String _ohnePraefix(String name) {
    final klein = name.toLowerCase();
    for (final praefix in praefixe) {
      if (!klein.startsWith(praefix)) continue;
      final rest = name.substring(praefix.length);
      // Nur als ganzes Wort: hinter dem Präfix steht ein Leerzeichen oder
      // nichts mehr.
      if (rest.isNotEmpty && !rest.startsWith(' ')) continue;
      return rest.trim();
    }
    return name;
  }

  /// Schneidet Suffixe ab, **bis keines mehr passt**: `… SA ohne Auflistung`
  /// trägt zwei davon, und welche Reihenfolge eine Kanzleidatei wählt, ist
  /// nicht vorherzusagen.
  static String _ohneSuffix(String name) {
    var rest = name;
    var geschnitten = true;
    while (geschnitten) {
      geschnitten = false;
      final klein = rest.toLowerCase();
      for (final suffix in suffixe) {
        if (!klein.endsWith(suffix)) continue;
        rest = rest.substring(0, rest.length - suffix.length).trim();
        geschnitten = true;
        break;
      }
    }
    return rest;
  }
}
