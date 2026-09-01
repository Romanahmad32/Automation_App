/// Wer da angeschrieben wird. Bestimmt die Anrede und das Symbol am Vorschlag.
///
/// **Nicht** die Textvorlage: Die wählt der Anwalt von Hand (§4.7). Hier stand
/// einmal „je Empfängertyp eine eigene" — das ging nicht auf, weil Mandant und
/// Versicherung standardmässig **eine gemeinsame** Mail bekommen und ein
/// Mandantenanschreiben dort nicht hineinpasst.
enum EmpfaengerArt {
  mandant('Mandant'),
  versicherung('Versicherung'),

  /// Noch von niemandem erzeugt: Vorschläge kommen bisher nur aus dem Vorgang
  /// (Mandant) und aus der Zentralruf-Antwort (Versicherung). Der Wert steht
  /// bereit für eine eingetippte Adresse ohne solche Herkunft — sie trägt dann
  /// weder die Anrede des Mandanten noch die der Versicherung.
  sonstige('Weitere');

  final String bezeichnung;

  const EmpfaengerArt(this.bezeichnung);
}
