/// Lebenszyklus eines Vorgangs — von der Zentralruf-Anfrage bis zum Versand.
/// Die Reihenfolge der Werte entspricht dem Fortschritt; [istAbgeschlossen]
/// markiert den Punkt, ab dem die laufende Auftragsnummer hochgezählt und die
/// Zeile ins Sachgebiete-Register geschrieben wird (§4.8, §6.2).
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

  /// Der Status, der nach einem Fortschritt auf [ziel] gilt: [ziel] selbst,
  /// solange es hinter dem eigenen liegt — sonst der eigene.
  ///
  /// Der Vorgang läuft **nur vorwärts**: Wer zum zweiten Schreiben ablegt, hat
  /// deshalb keinen versendeten Vorgang zurück auf „abgelegt" gesetzt. Steht
  /// hier und nicht als `status.index < ziel.index` an jeder Aufrufstelle, weil
  /// jede davon die Regel sonst selbst noch einmal richtig treffen muss — und
  /// weil ein `if` um die Zuweisung herum die Zuweisung **ganz** ausliess: So
  /// entstand der Fehler aus #133, bei dem die zweite Ablage auch Dokumentpfad
  /// und Aktenordner nicht mehr schrieb.
  VorgangStatus vorwaertsAuf(VorgangStatus ziel) =>
      ziel.index > index ? ziel : this;

  /// Liest einen [VorgangStatus] aus seinem persistierten [value]. Unbekannte
  /// oder fehlende Werte fallen tolerant auf [VorgangStatus.angefragt] zurück.
  static VorgangStatus fromValue(String? input) {
    for (final status in VorgangStatus.values) {
      if (status.value == input) return status;
    }
    return VorgangStatus.angefragt;
  }
}
