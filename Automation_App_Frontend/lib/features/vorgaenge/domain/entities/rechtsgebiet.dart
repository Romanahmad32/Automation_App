/// Rechtsgebiet eines Vorgangs — die Sachgebiete-Spalte des Auftragsregisters
/// (mehrseitige Word-Tabelle). Verkehrsrecht ist der fachliche Schwerpunkt der
/// Kanzlei und damit der Standardwert.
enum Rechtsgebiet {
  verkehrsrecht(name: 'Verkehrsrecht', value: 'verkehrsrecht'),
  arbeitsrecht(name: 'Arbeitsrecht', value: 'arbeitsrecht'),
  strafrecht(name: 'Strafrecht', value: 'strafrecht'),
  familienrecht(name: 'Familienrecht', value: 'familienrecht'),
  verwaltungsrecht(name: 'Verwaltungsrecht', value: 'verwaltungsrecht'),
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
