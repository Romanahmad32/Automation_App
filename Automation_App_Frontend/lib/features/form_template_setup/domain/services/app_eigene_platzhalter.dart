/// Platzhalter, die die App beim Erzeugen des Dokuments **selbst** füllt:
/// die Schadensaufstellung und die RVG-Kostenberechnung (Issue #35, #31).
///
/// Diese Namen dürfen nie als Eingabefeld übernommen werden und nie Pflicht
/// sein — ein solches Feld ließe sich von Hand nicht sinnvoll füllen und
/// sperrte das Formular dauerhaft.
///
/// Die Liste spiegelt die Ersetzung im Backend
/// (`DamageListingTable.AddRvgReplacements`); ein neuer app-eigener
/// Platzhalter gehört an beide Stellen.
class AppEigenePlatzhalter {
  const AppEigenePlatzhalter._();

  /// Die Namen, wie sie in der Word-Vorlage stehen (`{{RvgNetto}}` …).
  static const Set<String> namen = {
    'Schadensaufstellung',
    'Gegenstandswert',
    'Gebuehrensatz',
    'Geschaeftsgebuehr',
    'Auslagenpauschale',
    'RvgNetto',
    'RvgUmsatzsteuer',
    'RvgBrutto',
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
