/// Die vier Sichten auf den Posteingang (REQUIREMENTS.md §4.3, Issue #134) —
/// als `ChoiceChip`-Leiste dargestellt: genau eine gilt zugleich
/// (`lib/core/theme/presentation/auswahl_themes.dart`).
enum PosteingangFilter {
  /// Alles, ungefiltert — die Vorgabe.
  alle,

  /// Nur Nachrichten mit einer erkannten Zentralruf-Antwort, egal ob sie noch
  /// offen ist oder schon übernommen wurde.
  zentralruf,

  /// Nur Nachrichten mit einem erkannten Vorgangsbezug (sicher oder
  /// vermutet, siehe `VorgangsbezugErkenner`).
  mitVorgang,

  /// Nachrichten ohne erkennbaren Vorgangsbezug.
  ohneBezug,
}
