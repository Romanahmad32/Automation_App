/// Zieht eine einzelne Angabe in einem **von Hand bearbeiteten** Mailtext nach
/// (§4.7, ergänzt am 02.09.2026).
///
/// Der Fall: Sobald der Anwalt selbst in den Text geschrieben hat, hört die
/// Ableitung auf — sonst verlöre er beim nächsten Klick, was er getippt hat.
/// Die Chips über dem Betreff blieben dabei aber anfassbar und liefen **still
/// leer**: Wer die Anrede von „Herr" auf „Frau" umstellte, sah nichts
/// geschehen und erfuhr auch nicht, warum.
///
/// Hier ist der Mittelweg: Was die App zuletzt selbst eingesetzt hat, kennt sie
/// wörtlich — und genau diese Stelle darf sie austauschen. Alles andere bleibt
/// stehen. Das gilt nur für Angaben, die als **zusammenhängender Text** in der
/// Mail stehen (Anredezeile, Zusatzgruß); die Anredeart beugt Wörter mitten im
/// Satz und die Vorlage schreibt den ganzen Text — dort wäre jede Ersetzung
/// geraten, und darum sagt der Dialog es stattdessen.
class TextNachtrag {
  const TextNachtrag._();

  /// [text] mit [alt] gegen [neu] getauscht, oder **null**, wenn nichts zu tun
  /// war: [alt] ist leer, steht nicht (mehr) im Text, oder lautet schon wie
  /// [neu].
  ///
  /// Null ist die Auskunft „hier greift die Ersetzung nicht" — der Aufrufer
  /// lässt den Text dann unangetastet, und der Hinweis am Formular bleibt die
  /// einzige Antwort. Ein leerer String wäre diese Auskunft **nicht**: Er
  /// hieße „der Text ist jetzt leer".
  ///
  /// Getauscht wird nur das **erste** Vorkommen. Eine Anredezeile steht
  /// einmal; „Sehr geehrte Damen und Herren" ein zweites Mal weiter unten zu
  /// ersetzen wäre ein Eingriff in einen Satz, den der Anwalt geschrieben hat.
  static String? ersetzt(
    String text, {
    required String alt,
    required String neu,
  }) {
    final gesucht = alt.trim();
    if (gesucht.isEmpty || gesucht == neu.trim()) return null;

    final zeilen = text.split('\n');
    final nummer = zeilen.indexWhere((zeile) => zeile.contains(gesucht));
    if (nummer < 0) return null;

    final ersetzt = zeilen[nummer].replaceFirst(gesucht, neu);
    if (neu.trim().isNotEmpty || !_nurSatzzeichen(ersetzt)) {
      zeilen[nummer] = ersetzt;
      return zeilen.join('\n');
    }

    // Ohne Ersatz bleibt von der Zusatzgruß-Zeile nur ihr Komma übrig. Dann
    // geht die Zeile mit — dieselbe Regel wie beim Erzeugen, wo ein leerer
    // Platzhalter seine ganze Zeile mitnimmt (`MailVorlagenFueller`). Stand
    // die Angabe mitten in einem Satz, bleibt die Zeile und verliert nur sie.
    zeilen.removeAt(nummer);
    if (nummer > 0 &&
        nummer < zeilen.length &&
        zeilen[nummer - 1].trim().isEmpty &&
        zeilen[nummer].trim().isEmpty) {
      // Zwei Leerzeilen hintereinander sind der Rest der entfallenen Zeile —
      // der Absatzabstand ist eine, nicht zwei.
      zeilen.removeAt(nummer);
    }
    return zeilen.join('\n');
  }

  /// Anrede **und** Zusatzgruß in einem Zug — samt der Merker, die danach
  /// gelten.
  ///
  /// Ein Aufruf statt zweier, weil die zweite Ersetzung auf dem Ergebnis der
  /// ersten arbeiten muss: Beide können in derselben Zeile stehen („Sehr
  /// geehrter Herr Müller, Salamu aleikum").
  ///
  /// Der zurückgegebene Merker zieht **nur bei Erfolg** mit. Fand sich die
  /// alte Fassung nicht, hat der Anwalt sie selbst umgeschrieben — dann gehört
  /// die Stelle ihm, und der nächste Versuch soll dort auch nichts mehr
  /// suchen.
  static ({String text, String anrede, String zusatzgruss}) nachgezogen(
    String text, {
    required String alteAnrede,
    required String neueAnrede,
    required String alterGruss,
    required String neuerGruss,
  }) {
    var stand = text;
    var anrede = alteAnrede;
    var gruss = alterGruss;

    final mitAnrede = ersetzt(stand, alt: alteAnrede, neu: neueAnrede);
    if (mitAnrede != null) {
      stand = mitAnrede;
      anrede = neueAnrede;
    }

    final mitGruss = ersetzt(stand, alt: alterGruss, neu: neuerGruss);
    if (mitGruss != null) {
      stand = mitGruss;
      gruss = neuerGruss;
    }

    return (text: stand, anrede: anrede, zusatzgruss: gruss);
  }

  /// Ob von der Zeile nur noch Satzzeichen und Zwischenraum übrig sind.
  static bool _nurSatzzeichen(String zeile) =>
      RegExp(r'^[\s,;:.!?\-–—]*$').hasMatch(zeile);
}
