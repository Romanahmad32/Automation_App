/// Rechtsgebiet eines Vorgangs — die Sachgebiete-Spalte des Auftragsregisters
/// (mehrseitige Word-Tabelle). Verkehrsrecht ist der fachliche Schwerpunkt der
/// Kanzlei und damit der Standardwert.
///
/// Der Satz deckt die Sachgebiete ab, die im gewachsenen Register der Kanzlei
/// tatsaechlich vorkommen. Verkehrsstrafrecht, Zivilrecht und Vertragsrecht
/// sind spaeter dazugekommen (#40): sie stehen dort seit Jahren, fehlten hier
/// aber — ohne sie faellt rund ein Sechstel des Bestands still auf
/// [verkehrsrecht] zurueck, weil [fromValue] bewusst tolerant ist.
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

  /// Platzhalter, wenn am Vorgang kein Rechtsgebiet steht. Muss zu
  /// `RechtsgebietAnzeige.Unbekannt` im Backend passen.
  static const String unbekannt = '—';

  /// Anzeigename des **gespeicherten** Werts — die vierte Registerspalte.
  ///
  /// Muss dieselbe Antwort geben wie `RechtsgebietAnzeige.Fuer` im Backend,
  /// sonst zeigt die Ansicht ein anderes Sachgebiet an, als in der
  /// Register-Datei steht. Deshalb liest sie den gespeicherten Wert und geht
  /// **nicht** über [fromValue]: Dessen Toleranz ist für die Bearbeitung
  /// gedacht — ein fremder Persistenzstand soll den Vorgang nicht unlesbar
  /// machen. Als Registerzeile wäre sie eine Behauptung: Ein nie erfasstes
  /// Sachgebiet steht in einem Sachgebiete-Register als [unbekannt] und nicht
  /// als „Verkehrsrecht".
  static String anzeige(String? gespeichert) {
    final roh = (gespeichert ?? '').trim();
    if (roh.isEmpty) return unbekannt;
    return roh[0].toUpperCase() + roh.substring(1);
  }

  /// Liest ein [Rechtsgebiet] aus seinem persistierten [value]. Unbekannte oder
  /// fehlende Werte fallen tolerant auf [Rechtsgebiet.verkehrsrecht] zurück:
  /// ein älterer/fremder Persistenzstand soll den Vorgang nicht unlesbar machen.
  /// Für die **Anzeige** im Register ist deshalb [anzeige] zuständig.
  static Rechtsgebiet fromValue(String? input) {
    for (final gebiet in Rechtsgebiet.values) {
      if (gebiet.value == input) return gebiet;
    }
    return Rechtsgebiet.verkehrsrecht;
  }
}
