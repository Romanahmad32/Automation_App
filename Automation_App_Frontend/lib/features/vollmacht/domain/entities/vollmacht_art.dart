/// Die drei Vollmachtsvorlagen der Kanzlei (§4.11). Der Vollmachtstext ist in
/// allen dreien derselbe; sie unterscheiden sich im Kopf („in Sachen",
/// „wegen") und die Unfallvorlage zusätzlich im Abschnitt für Telefon, E-Mail
/// und Konto.
///
/// [wert] ist die Schreibweise des Vertrags (`VollmachtArten.Wert` im Dienst).
enum VollmachtArt {
  unfallsachen('unfallsachen', 'Unfallsachen'),
  bussgeldsachen('bussgeldsachen', 'Bußgeldsachen'),
  strafsache('strafsache', 'Strafsache');

  final String wert;
  final String titel;

  const VollmachtArt(this.wert, this.titel);

  /// Die Art zu einem Vertragswert; null bei einem unbekannten.
  static VollmachtArt? ausWert(String? wert) {
    for (final art in values) {
      if (art.wert == wert) return art;
    }
    return null;
  }
}
