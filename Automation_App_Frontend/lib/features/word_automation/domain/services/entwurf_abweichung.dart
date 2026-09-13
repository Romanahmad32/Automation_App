/// Was am angefangenen Ausfüllstand überhaupt aufzuheben ist: die Felder, die
/// der Anwalt gegenüber der **Vorbelegung** geändert hat (#133).
///
/// Warum nicht einfach das ganze Formular: Der Tippstand meldet immer **alle**
/// Felder, also auch jedes unberührte, vorbelegte. Läge der ganze Stand am
/// Vorgang, fröre er die Vorbelegung ein — trifft später eine Zentralruf-Antwort
/// mit dem gegnerischen Versicherer ein, verdeckte der alte Stand sie, und im
/// Formular stünde weiter, was beim ersten Anlauf dort stand. Gespeichert wird
/// deshalb nur der Unterschied; alles andere holt sich das Formular jedes Mal
/// frisch aus dem Bestand.
///
/// Reine Funktion ohne Zustand: Sie bekommt beide Seiten übergeben und lässt
/// sich damit einzeln prüfen, ohne Cubit und ohne Widget.
class EntwurfAbweichung {
  const EntwurfAbweichung._();

  /// Die Teil-Map der abweichenden Felder — genau das, was als Entwurf am
  /// Vorgang landet.
  ///
  /// [werte] ist der gemeldete Formularstand (Feldbezeichnung → Wert, wie
  /// `VorgangEntwurf.feldWerte`), [vorbelegung] das, was das Formular ohne den
  /// Stand zeigen würde; ein fehlender Eintrag zählt als leerer Wert.
  ///
  /// Verglichen wird beidseitig gestutzt und sonst exakt — ein Leerzeichen am
  /// Rand ist nichts, was der Anwalt gemeint hat, jede andere Abweichung schon.
  /// Der **Wert** wandert dabei ungestutzt in die Map: Was aufgehoben wird,
  /// soll bei der Rückkehr Zeichen für Zeichen wieder dastehen.
  ///
  /// Ein geleertes Feld bleibt drin (leerer Wert gegen eine nicht leere
  /// Vorbelegung ist eine Abweichung): „Ich will hier nichts stehen haben" ist
  /// eine Entscheidung, und ohne sie käme die Vorbelegung bei der Rückkehr
  /// zurück.
  static Map<String, String> nurAbweichende({
    required Map<String, String> werte,
    required Map<String, String> vorbelegung,
  }) => {
    for (final eintrag in werte.entries)
      if (eintrag.value.trim() != (vorbelegung[eintrag.key] ?? '').trim())
        eintrag.key: eintrag.value,
  };
}
