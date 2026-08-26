/// Wer da angeschrieben wird. Bestimmt die Anrede, das Symbol am Vorschlag und
/// später (§4.7) die Textvorlage — je Empfängertyp eine eigene.
enum EmpfaengerArt {
  mandant('Mandant'),
  versicherung('Versicherung'),
  sonstige('Weitere');

  final String bezeichnung;

  const EmpfaengerArt(this.bezeichnung);
}
