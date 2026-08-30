/// Rechtsgebiet eines Vorgangs — die Sachgebiete-Spalte des Auftragsregisters
/// (mehrseitige Word-Tabelle). Verkehrsrecht ist der fachliche Schwerpunkt der
/// Kanzlei und damit der Standardwert.
///
/// Der Satz deckt die Sachgebiete ab, die im gewachsenen Register der Kanzlei
/// tatsaechlich vorkommen. Verkehrsstrafrecht, Zivilrecht und Vertragsrecht
/// sind spaeter dazugekommen (#40): sie stehen dort seit Jahren, fehlten hier
/// aber — ohne sie faellt rund ein Sechstel des Bestands auf [sonstiges]
/// zurueck, und zwar still, weil [fromValue] bewusst tolerant ist.
enum Rechtsgebiet {
  verkehrsrecht(name: 'Verkehrsrecht', value: 'verkehrsrecht'),
  verkehrsstrafrecht(name: 'Verkehrsstrafrecht', value: 'verkehrsstrafrecht'),
  arbeitsrecht(name: 'Arbeitsrecht', value: 'arbeitsrecht'),
  strafrecht(name: 'Strafrecht', value: 'strafrecht'),
  familienrecht(name: 'Familienrecht', value: 'familienrecht'),
  verwaltungsrecht(name: 'Verwaltungsrecht', value: 'verwaltungsrecht'),
  zivilrecht(name: 'Zivilrecht', value: 'zivilrecht'),
  vertragsrecht(name: 'Vertragsrecht', value: 'vertragsrecht'),
  sonstiges(name: 'Sonstiges', value: 'sonstiges');

  final String name;

  /// Stabiler Schlüssel für die Persistenz. Bewusst getrennt von [toString],
  /// damit Änderungen an Debug-Ausgaben das Dateiformat nie beeinflussen
  /// (gleiche Konvention wie InputType).
  final String value;

  const Rechtsgebiet({required this.name, required this.value});

  String get displayName => name;

  /// Liest ein [Rechtsgebiet] aus seinem persistierten [value]. Unbekannte oder
  /// fehlende Werte fallen tolerant auf [Rechtsgebiet.verkehrsrecht] zurück:
  /// ein älterer/fremder Persistenzstand soll den Vorgang nicht unlesbar machen.
  static Rechtsgebiet fromValue(String? input) {
    for (final gebiet in Rechtsgebiet.values) {
      if (gebiet.value == input) return gebiet;
    }
    return Rechtsgebiet.verkehrsrecht;
  }
}
