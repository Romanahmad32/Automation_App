/// In welcher Fassung das fertige Schreiben gespeichert wird — in der Akte
/// (§6.1) ebenso wie an einem frei gewählten Ort.
///
/// Die Word-Fassung ist die bearbeitbare, das PDF die versandfertige — beides
/// hat seinen Platz, und welche der Anwalt behalten will, entscheidet er im
/// Speicherschritt, für jeden der beiden Wege getrennt.
///
/// Daran hängt mehr als der Dateityp: Der Arbeitsordner des Vorgangs wird nach
/// der Ablage gelöscht (§4.6). Ohne Word-Fassung in der Akte bliebe damit
/// keine bearbeitbare Datei übrig — deshalb räumt `schliesseAblageAb` nur auf,
/// wenn die Word-Fassung abgelegt wurde.
enum AblageFormat {
  word('Word (.docx)'),
  pdf('PDF'),
  beide('Word + PDF');

  const AblageFormat(this.bezeichnung);

  /// Beschriftung in der Auswahl.
  final String bezeichnung;

  bool get mitWord => this != AblageFormat.pdf;

  bool get mitPdf => this != AblageFormat.word;
}
