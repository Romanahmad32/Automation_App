/// Wer da angeschrieben wird. Bestimmt die Anrede, das Symbol am Vorschlag und
/// später (§4.7) die Textvorlage — je Empfängertyp eine eigene.
enum EmpfaengerArt {
  mandant('Mandant'),
  versicherung('Versicherung'),

  /// Noch von niemandem erzeugt: Vorschläge kommen bisher nur aus dem Vorgang
  /// (Mandant) und aus der Zentralruf-Antwort (Versicherung). Der Wert steht
  /// für die pflegbaren Mail-Textvorlagen bereit (§4.7, §5.3), bei denen der
  /// Anwalt eine Adresse ohne solche Herkunft anschreibt — dann trägt sie
  /// weder die Anrede des Mandanten noch die der Versicherung.
  sonstige('Weitere');

  final String bezeichnung;

  const EmpfaengerArt(this.bezeichnung);
}
