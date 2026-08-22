/// Wie mit einer bereits vorhandenen gleichnamigen Datei im Fall-Ordner
/// umzugehen ist (§6.1).
///
/// Die Entscheidung gehört dem Anwalt, nicht dem Programm: in der Akte liegt
/// die verbindliche Fassung eines Schreibens. Sie stillschweigend zu ersetzen
/// hieße, ein bereits abgelegtes Dokument zu verlieren, ohne dass es jemand
/// merkt.
enum AblageStrategie {
  /// Nichts überschreiben, sondern zurückfragen — der Standard.
  fragen,

  /// Die vorhandene Datei ersetzen; vom Anwalt bestätigt.
  ersetzen,

  /// Beide behalten: unter dem nächsten freien Namen „… (2).docx" ablegen.
  beideBehalten,
}
