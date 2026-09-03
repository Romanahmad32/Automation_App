/// Ein Platzhalter, den die App selbst füllt: sein Name in der Word-Vorlage,
/// was er einsetzt und wie das Ergebnis aussieht.
class AppEigenerPlatzhalter {
  /// Der Name ohne Klammern, so wie das Backend ihn ersetzt (`RvgNetto`).
  final String name;

  /// Woher der Wert kommt — ein Satz, den der Anwalt ohne Vorwissen versteht.
  final String erklaerung;

  /// Das Ergebnis für die Beispielrechnung in [AppEigenePlatzhalter.beispiel].
  final String beispiel;

  const AppEigenerPlatzhalter({
    required this.name,
    required this.erklaerung,
    required this.beispiel,
  });
}

/// Platzhalter, die die App beim Erzeugen des Dokuments **selbst** füllt:
/// die Schadensaufstellung und die RVG-Kostenberechnung (Issue #35, #31).
///
/// Diese Namen dürfen nie als Eingabefeld übernommen werden und nie Pflicht
/// sein — ein solches Feld ließe sich von Hand nicht sinnvoll füllen und
/// sperrte das Formular dauerhaft.
///
/// Die Liste spiegelt die Ersetzung im Backend (`RvgPlatzhalter.Namen` und
/// `DamageListingTable.Placeholder`); ein neuer app-eigener Platzhalter gehört
/// an beide Stellen, und `app_eigene_platzhalter_test.dart` hält sie zusammen.
class AppEigenePlatzhalter {
  const AppEigenePlatzhalter._();

  /// Die Rechnung, aus der die Beispielwerte stammen. Sie ist im Backend
  /// gepinnt (`RvgPlatzhalterTests`), damit die angezeigten Zahlen nicht
  /// auseinanderlaufen mit dem, was im Dokument landet.
  static const String beispiel =
      'Beispiel: Aufstellung über 4.250,00 €, Gebührensatz 1,3, mit '
      'Umsatzsteuer.';

  /// Alle app-eigenen Platzhalter in der Reihenfolge, in der sie im Brief
  /// aufeinander aufbauen — von der Summe der Positionen bis zur Zahl, die der
  /// Gegner überweisen soll.
  static const List<AppEigenerPlatzhalter> eintraege = [
    AppEigenerPlatzhalter(
      name: 'Schadensaufstellung',
      erklaerung:
          'Die Tabelle mit allen Positionen, Zwischensumme und Anwaltskosten. '
          'Nur in der Datei „mit Auflistung“.',
      beispiel: '(Tabelle)',
    ),
    AppEigenerPlatzhalter(
      name: 'Gegenstandswert',
      erklaerung: 'Summe der Positionen — die Zwischensumme ohne RA-Kosten.',
      beispiel: '4.250,00',
    ),
    AppEigenerPlatzhalter(
      name: 'Gebuehrensatz',
      erklaerung: 'Der gewählte Satz der Geschäftsgebühr (Regelsatz 1,3).',
      beispiel: '1,3',
    ),
    AppEigenerPlatzhalter(
      name: 'Geschaeftsgebuehr',
      erklaerung: 'Wertgebühr × Gebührensatz, oder der korrigierte Betrag.',
      beispiel: '460,85',
    ),
    AppEigenerPlatzhalter(
      name: 'Auslagenpauschale',
      erklaerung: 'Nr. 7002 VV RVG — 20 % der Gebühr, höchstens 20,00 €.',
      beispiel: '20,00',
    ),
    AppEigenerPlatzhalter(
      name: 'RvgNetto',
      erklaerung: 'Geschäftsgebühr und Auslagenpauschale zusammen.',
      beispiel: '480,85',
    ),
    AppEigenerPlatzhalter(
      name: 'RvgUmsatzsteuer',
      erklaerung:
          '19 % auf den Nettobetrag — 0,00 bei vorsteuerabzugsberechtigten '
          'Mandanten.',
      beispiel: '91,36',
    ),
    AppEigenerPlatzhalter(
      name: 'RvgBrutto',
      erklaerung: 'Die Anwaltskosten insgesamt.',
      beispiel: '572,21',
    ),
    AppEigenerPlatzhalter(
      name: 'Gesamtforderung',
      erklaerung:
          'Zwischensumme plus Anwaltskosten — die Zahl, die der Gegner '
          'überweisen soll.',
      beispiel: '4.822,21',
    ),
  ];

  /// Die Namen, wie sie in der Word-Vorlage stehen (`{{RvgNetto}}` …).
  static final Set<String> namen = {
    for (final eintrag in eintraege) eintrag.name,
  };

  static final Set<String> _kleingeschrieben = namen
      .map((name) => name.toLowerCase())
      .toSet();

  /// Ob [name] einen app-eigenen Platzhalter meint.
  ///
  /// Verglichen wird nur ohne Groß-/Kleinschreibung — bewusst **nicht** über
  /// `FeldDatenquelleErkennung.normalisiere`: Das Backend ersetzt exakt diese
  /// Namen (`RegexOptions.IgnoreCase`); ein `{{Rvg-Netto}}` würde dort *nicht*
  /// gefüllt und ist deshalb auch hier nicht app-eigen.
  static bool istAppEigen(String name) =>
      _kleingeschrieben.contains(name.trim().toLowerCase());
}
