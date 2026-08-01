/// Anrede/Geschlecht eines Mandanten. Bestimmt, wie der Mandant in Vorlagen und
/// E-Mails angesprochen wird (z. B. „Sehr geehrter Herr …" / „Sehr geehrte
/// Frau …"). Bewusst getrennter, stabiler [value] für die Persistenz — analog
/// zu `InputType`.
enum Anrede {
  herr(name: 'Herr', value: 'herr'),
  frau(name: 'Frau', value: 'frau'),
  keine(name: 'Keine Angabe', value: 'keine');

  final String name;

  /// Stabiler Schlüssel für die Persistenz (mandanten.json). Bewusst getrennt
  /// von [toString], damit Debug-Ausgaben das Dateiformat nie beeinflussen.
  final String value;

  const Anrede({required this.name, required this.value});

  String get displayName => name;

  /// Kurzform für die Briefadresse („Herr"/„Frau"), bei [keine] leer.
  String get kurzform => this == keine ? '' : name;

  /// Vollständige Brief-/E-Mail-Anrede inkl. Nachname, z. B.
  /// „Sehr geehrter Herr Müller". Bei [keine] (oder fehlendem Nachnamen) fällt
  /// sie auf die geschlechtsneutrale Form „Sehr geehrte Damen und Herren"
  /// zurück.
  String briefanrede(String nachname) {
    final n = nachname.trim();
    return switch (this) {
      herr when n.isNotEmpty => 'Sehr geehrter Herr $n',
      frau when n.isNotEmpty => 'Sehr geehrte Frau $n',
      _ => 'Sehr geehrte Damen und Herren',
    };
  }

  /// Liest eine [Anrede] aus ihrem persistierten [value]. Unbekannte oder
  /// fehlende Werte fallen tolerant auf [keine] zurück, damit ältere
  /// Mandantendatensätze (ohne dieses Feld) weiterhin laden.
  static Anrede fromValue(String? input) {
    for (final anrede in Anrede.values) {
      if (anrede.value == input) return anrede;
    }
    return keine;
  }
}
