enum InputType {
  integer(name: 'Ganzzahl', value: 'integer'),
  text(name: 'Textfeld', value: 'text'),
  date(name: 'Datum', value: 'date'),
  decimal(name: 'Kommazahl', value: 'decimal'),

  /// Kfz-Kennzeichen in der Domaenen-Konvention `HG-E 1427`. Ein Textfeld mit
  /// Formatpruefung und der Auswahlhilfe aus den bekannten Kennzeichen des
  /// Vorgangs und des Mandantenregisters (#17).
  ///
  /// **Bestehende Vorlagen bleiben unberuehrt.** Der Wert `kennzeichen` wird
  /// erst in eine Vorlage geschrieben, wenn ihn jemand am Feld auswaehlt; bis
  /// dahin steht dort weiter `text`. Das Backend haelt `fields` als opakes
  /// JSON und reicht den Wert nur durch — nur Dart kennt das Schema (siehe
  /// FALLSTRICKE.md), und [fromValue] wirft deshalb bei allem Unbekannten.
  kennzeichen(name: 'Kennzeichen', value: 'kennzeichen');

  final String name;

  /// Stabiler Schluessel fuer die Persistenz. Bewusst getrennt von [toString],
  /// damit Aenderungen an Debug-Ausgaben das Dateiformat nie beeinflussen.
  final String value;

  const InputType({required this.name, required this.value});

  String get displayName => name;

  /// Liest einen [InputType] aus seinem persistierten [value].
  /// Wirft eine [FormatException] bei unbekanntem Wert, damit beschaedigte
  /// Vorlagendateien beim Laden sauber als solche erkannt werden.
  static InputType fromValue(String input) {
    for (final type in InputType.values) {
      if (type.value == input) return type;
    }
    throw FormatException('Unbekannter InputType: $input');
  }
}
