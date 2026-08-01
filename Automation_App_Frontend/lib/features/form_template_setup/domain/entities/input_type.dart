enum InputType {
  integer(name: 'Ganzzahl eingabe', value: 'integer'),
  text(name: 'Textfeld', value: 'text'),
  date(name: 'Datum eigabe', value: 'date'),
  decimal(name: 'Kommazahl eingabe', value: 'decimal');

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
