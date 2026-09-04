/// Ein Wert, der in einem `AuswahlDialog` zur Wahl steht, samt einer Zeile,
/// die sagt, woher er kommt.
///
/// Bewusst zwei blanke Zeichenketten und **keine** Domänen-Typen: Dieser
/// Baustein liegt unter `core/`, gilt projektweit und darf deshalb kein Feature
/// kennen. Wer eine Aufzählung als Herkunft hat (etwa `PrefillQuelle`), gibt
/// ihren Anzeigetext herein — die Übersetzung gehört dem Feature.
class AuswahlKandidat {
  /// Der Wert, der bei Auswahl ins Feld geschrieben wird — er ist auch der
  /// Titel der Zeile im Dialog.
  final String wert;

  /// Kleingeschriebener Einschub für die Untertitelzeile, z. B. „aus dem
  /// Mandantenregister".
  final String herkunft;

  const AuswahlKandidat(this.wert, this.herkunft);
}
