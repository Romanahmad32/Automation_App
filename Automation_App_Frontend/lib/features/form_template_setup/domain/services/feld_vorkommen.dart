/// In welcher der beiden Word-Dateien einer Vorlage ein Feldname als
/// {{Platzhalter}} vorkommt (#35 Teil 3) — je Feld angezeigt, damit sichtbar
/// ist, welches Schreiben ein Feld überhaupt braucht, und damit ein vertippter
/// Name („in keiner Datei") beim Einrichten auffällt statt im Brief.
enum FeldVorkommen {
  beide('beide', 'Kommt in beiden Word-Dateien vor.'),
  nurHgn('nur HGN', 'Kommt nur in der Datei ohne Auflistung (HGN) vor.'),
  nurAuflistung('nur Auflistung', 'Kommt nur in der Datei mit Auflistung vor.'),
  inKeinerDatei(
    'in keiner Datei',
    'Kommt in keiner der Word-Dateien vor — Tippfehler im Namen? '
        'Das Feld bleibt beim Erzeugen wirkungslos.',
  );

  /// Kurztext auf dem Kennzeichen.
  final String anzeige;

  /// Satz für den Tooltip.
  final String erklaerung;

  const FeldVorkommen(this.anzeige, this.erklaerung);

  /// Bestimmt das Vorkommen von [name]; null, wenn (noch) keine der beiden
  /// Platzhaltermengen bekannt ist oder kein Name eingetragen wurde — dann
  /// gibt es nichts zu sagen.
  ///
  /// Der Vergleich läuft ohne Groß-/Kleinschreibung, wie die Ersetzung im
  /// Backend (`RegexOptions.IgnoreCase`).
  static FeldVorkommen? bestimme(
    String? name, {
    required Set<String>? ohneAuflistung,
    required Set<String>? mitAuflistung,
  }) {
    final gesucht = name?.trim().toLowerCase();
    if (gesucht == null || gesucht.isEmpty) return null;
    if (ohneAuflistung == null && mitAuflistung == null) return null;

    bool enthaelt(Set<String>? platzhalter) =>
        platzhalter != null &&
        platzhalter.any((p) => p.trim().toLowerCase() == gesucht);

    final inOhne = enthaelt(ohneAuflistung);
    final inMit = enthaelt(mitAuflistung);
    if (inOhne && inMit) return FeldVorkommen.beide;
    if (inOhne) return FeldVorkommen.nurHgn;
    if (inMit) return FeldVorkommen.nurAuflistung;
    return FeldVorkommen.inKeinerDatei;
  }
}
