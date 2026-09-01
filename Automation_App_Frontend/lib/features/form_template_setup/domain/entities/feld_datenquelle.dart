/// Explizite Datenquelle eines Vorlagenfelds: Womit das Feld beim Ausfüllen aus
/// dem gewählten [Vorgang] (Mandant + Zentralruf-Antwort + Vorgangsdaten)
/// vorbelegt wird. Ersetzt das fehleranfällige Raten über den Feldnamen — der
/// Anwalt ordnet jedem Feld die Quelle einmal eindeutig zu.
///
/// [keine] bedeutet: keine feste Zuordnung. Solche Felder löst
/// `FeldDatenquelleErkennung` beim Ausfüllen über den Feldnamen auf
/// (Abwärtskompatibilität für bestehende Vorlagen, die noch keine Quelle
/// gesetzt haben).
///
/// Die Aufteilung folgt einer Regel: **Was einzeln gespeichert ist, bekommt
/// eine eigene Quelle; Zusammensetzungen schreibt man als zwei Platzhalter
/// nebeneinander in die Word-Datei.** Einzige Ausnahme sind die Anschriften —
/// sie lassen fehlende Teile weg, was nebeneinandergesetzte Platzhalter nicht
/// können (sie hinterlassen dort eine Leerstelle).
enum FeldDatenquelle {
  keine(name: 'Keine (automatisch erraten)', value: 'keine'),

  // Mandant / Geschädigter (aus dem Mandantenregister bzw. dem Vorgang).
  mandantName(name: 'Mandant · Name', value: 'mandantName'),
  mandantVorname(name: 'Mandant · Vorname', value: 'mandantVorname'),
  mandantNachname(name: 'Mandant · Nachname', value: 'mandantNachname'),
  mandantBriefanrede(
    name: 'Mandant · Briefanrede („Sehr geehrter Herr …“)',
    value: 'mandantBriefanrede',
  ),
  mandantStrasse(name: 'Mandant · Straße & Hausnr.', value: 'mandantStrasse'),
  mandantPlz(name: 'Mandant · PLZ', value: 'mandantPlz'),
  mandantOrt(name: 'Mandant · Ort', value: 'mandantOrt'),
  mandantAnschrift(
    name: 'Mandant · Anschrift (Name, Straße, PLZ Ort)',
    value: 'mandantAnschrift',
  ),
  mandantEmail(name: 'Mandant · E-Mail', value: 'mandantEmail'),
  mandantTelefon(name: 'Mandant · Telefon', value: 'mandantTelefon'),

  // Gegnerische Versicherung (aus der Zentralruf-Antwort).
  versichererName(name: 'Versicherer · Name', value: 'versichererName'),
  versichererStrasse(
    name: 'Versicherer · Straße & Hausnr.',
    value: 'versichererStrasse',
  ),
  versichererPlz(name: 'Versicherer · PLZ', value: 'versichererPlz'),
  versichererOrt(name: 'Versicherer · Ort', value: 'versichererOrt'),
  versichererAdresse(
    name: 'Versicherer · Adresse (Straße, PLZ Ort – ohne Name)',
    value: 'versichererAdresse',
  ),
  versichererAnschrift(
    name: 'Versicherer · Anschrift (Name, Straße, PLZ Ort)',
    value: 'versichererAnschrift',
  ),
  versichererEmail(name: 'Versicherer · E-Mail', value: 'versichererEmail'),
  versichererTelefon(
    name: 'Versicherer · Telefon',
    value: 'versichererTelefon',
  ),
  versichererFax(name: 'Versicherer · Fax', value: 'versichererFax'),
  versicherungsscheinNr(
    name: 'Versicherungsschein-Nr.',
    value: 'versicherungsscheinNr',
  ),
  versicherungsbeginn(
    name: 'Versicherungsbeginn',
    value: 'versicherungsbeginn',
  ),

  // Vorgang / Unfall.
  kennzeichenGegner(name: 'Kennzeichen · Gegner', value: 'kennzeichenGegner'),
  kennzeichenMandant(
    name: 'Kennzeichen · Mandant/Geschädigter',
    value: 'kennzeichenMandant',
  ),
  unfalldatum(name: 'Unfalldatum', value: 'unfalldatum'),
  unfallort(name: 'Unfallort', value: 'unfallort'),
  unfalluhrzeit(name: 'Unfalluhrzeit', value: 'unfalluhrzeit'),
  polizeiVorgangsnummer(
    name: 'Polizei-Vorgangsnummer',
    value: 'polizeiVorgangsnummer',
  ),
  referenz(name: 'Referenz (vollständig)', value: 'referenz'),
  zeichen(
    name: 'Zeichen (ohne Kennzeichen)',
    value: 'zeichen',
    frueher: 'aktenzeichen',
  ),
  rechtsgebiet(name: 'Rechtsgebiet', value: 'rechtsgebiet');

  final String name;

  /// Stabiler Schlüssel für die Persistenz (getrennt von [toString], gleiche
  /// Konvention wie [InputType]/[Rechtsgebiet]).
  final String value;

  /// Ein früherer [value] derselben Quelle, der in bereits gespeicherten
  /// Vorlagen steht und weiterhin gelesen werden muss.
  ///
  /// Gibt es, weil [fromValue] unbekannte Werte still auf [keine] fallen lässt
  /// — ein umbenannter Schlüssel bräche also keinen Test und keine Meldung,
  /// sondern nur die Vorbelegung in jeder Bestandsvorlage, und das merkt erst
  /// der Anwalt am fehlenden Wert im Brief. Wer hier umbenennt, trägt den alten
  /// Wert hier ein; `feld_datenquelle_test.dart` hält beide Wege fest.
  final String? frueher;

  const FeldDatenquelle({
    required this.name,
    required this.value,
    this.frueher,
  });

  String get displayName => name;

  /// True für alles außer [keine] — also wenn eine feste Quelle gewählt wurde.
  bool get istGesetzt => this != FeldDatenquelle.keine;

  /// Liest eine [FeldDatenquelle] aus ihrem persistierten [value] — oder aus
  /// einem [frueher] geschriebenen. Unbekannte oder fehlende Werte fallen
  /// tolerant auf [keine] zurück, damit ein älterer/fremder Persistenzstand das
  /// Feld nicht unlesbar macht.
  static FeldDatenquelle fromValue(String? input) {
    for (final quelle in FeldDatenquelle.values) {
      if (quelle.value == input || quelle.frueher == input) return quelle;
    }
    return FeldDatenquelle.keine;
  }
}
