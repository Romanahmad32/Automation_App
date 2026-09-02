/// Wonach die Platzhalter in einer Auswahl sortiert werden (§4.7, §5.3).
///
/// Der Katalog der Vorgangsfelder ist über dreißig Einträge lang. Als eine
/// Liste ist er unbenutzbar — der Anwalt sucht „die Adresse der Versicherung"
/// und nicht den zweiundzwanzigsten Eintrag. Die Gruppe steht deshalb **am
/// Katalogeintrag** (`FeldDatenquelle.gruppe`) und nicht in der Oberfläche:
/// Eine Zuordnung dort wäre eine zweite Liste, die beim nächsten neuen Feld
/// stillschweigend unvollständig wird.
enum PlatzhalterGruppe {
  /// Was beim Verfassen dieser einen Mail entsteht — Anrede und Zusatzgruß.
  /// Kein Vorgangsfeld: Diese Werte stehen an keinem Vorgang (§4.7).
  verfassen(titel: 'Beim Verfassen gewählt'),

  mandant(titel: 'Mandant'),

  versicherer(titel: 'Gegnerische Versicherung'),

  vorgang(titel: 'Vorgang und Unfall'),

  /// Für [FeldDatenquelle.keine] — nichts anzubieten.
  ohne(titel: '');

  final String titel;

  const PlatzhalterGruppe({required this.titel});
}
