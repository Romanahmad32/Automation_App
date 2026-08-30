/// Fachliche Einordnung eines Akten-Ordners anhand des Präfixes im Ordnernamen
/// (§6.1). Im Stammordner der Kanzlei liegen alle Sachgebiete nebeneinander,
/// diese App bearbeitet aber nur Verkehrsunfallsachen: Bußgeld-, Straf- und
/// Familiensachen müssen keinem Mandanten zugeordnet werden und gehören darum
/// nicht in den Zuordnungsstapel.
///
/// [ohnePraefix] heißt ausdrücklich **nicht** „unbekannt, also wegsortieren":
/// ein Ordner, der nur „Max Mustermann" heißt, kann sehr wohl eine
/// Verkehrsunfallsache sein. Er bleibt deshalb sichtbar — die Heuristik darf
/// Arbeit ersparen, aber nichts verschlucken.
enum Aktentyp {
  verkehrsunfall('Verkehrsunfallsache'),
  bussgeld('Bußgeldsache'),
  straf('Strafsache'),
  familie('Familiensache'),
  ohnePraefix('Ohne Aktentyp im Namen');

  const Aktentyp(this.bezeichnung);

  /// Anzeigename für Filter und Gruppenüberschriften.
  final String bezeichnung;

  /// Kommt der Ordner als Verkehrsunfallsache in Frage? Nur diese stehen
  /// standardmäßig im Zuordnungsstapel, der Rest unter „Andere Ordner".
  bool get istUnfallkandidat =>
      this == Aktentyp.verkehrsunfall || this == Aktentyp.ohnePraefix;
}
