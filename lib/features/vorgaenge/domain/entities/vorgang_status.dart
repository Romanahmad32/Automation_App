/// Lebenszyklus eines Vorgangs — von der Zentralruf-Anfrage bis zum Versand.
/// Die Reihenfolge der Werte entspricht dem Fortschritt; [istAbgeschlossen]
/// markiert den Punkt, ab dem die laufende Auftragsnummer hochgezählt und die
/// Zeile ins Sachgebiete-Register geschrieben wird (Req. 3.2 / 3.7).
enum VorgangStatus {
  angefragt(name: 'Angefragt', value: 'angefragt'),
  beantwortet(name: 'Beantwortet', value: 'beantwortet'),
  erstellt(name: 'Erstellt', value: 'erstellt'),
  abgelegt(name: 'Abgelegt', value: 'abgelegt'),
  versendet(name: 'Versendet', value: 'versendet');

  final String name;

  /// Stabiler Schlüssel für die Persistenz (getrennt von [toString]).
  final String value;

  const VorgangStatus({required this.name, required this.value});

  String get displayName => name;

  /// True ab dem Abschluss des Auftrags (Versand). Auslöser für das Hochzählen
  /// der Auftragsnummer und den Registereintrag.
  bool get istAbgeschlossen => this == VorgangStatus.versendet;

  /// Liest einen [VorgangStatus] aus seinem persistierten [value]. Unbekannte
  /// oder fehlende Werte fallen tolerant auf [VorgangStatus.angefragt] zurück.
  static VorgangStatus fromValue(String? input) {
    for (final status in VorgangStatus.values) {
      if (status.value == input) return status;
    }
    return VorgangStatus.angefragt;
  }
}
