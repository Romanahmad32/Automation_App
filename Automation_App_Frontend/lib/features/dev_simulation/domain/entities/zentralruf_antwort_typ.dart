/// Welche der generischen Zentralruf-Antworten die Entwickler-Simulation
/// erzeugen soll. [wireName] ist der Wert, den die Backend-API erwartet
/// (String-Serialisierung des Backend-Enums `SimulationAntwortTyp`).
enum ZentralrufAntwortTyp {
  /// Standardfall: Versicherer wurde ermittelt (Positivantwort).
  versicherer('Versicherer'),

  /// Negativ-Antwort: kein Versicherer ermittelt.
  keinVersicherer('KeinVersicherer'),

  /// Zwischennachricht: Auskunft nicht sofort möglich, Folgemail kommt.
  zwischennachricht('Zwischennachricht');

  final String wireName;

  const ZentralrufAntwortTyp(this.wireName);
}
