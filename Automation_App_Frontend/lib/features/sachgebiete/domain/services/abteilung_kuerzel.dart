/// Regeln für Abteilungskürzel und Überschneidungen (§7.1).
///
/// Eine Abteilung ist ein Hauptsachgebiet mit optionalem Nebenbezug,
/// geschrieben als `Hauptkürzel/Nebenteil` (`C05/3` = Strafrecht mit
/// Verkehrsbezug). Der Nebenteil ist das Kürzel des Nebensachgebiets ohne
/// das Präfix `C0` (`C03` → `3`, `C03o` → `3o`, `C01a` → `1a`); die
/// Rückabbildung setzt `C0` wieder davor.
///
/// Kürzel werden ohne Leerzeichen geführt: Das Referenzformat (§4.2) trennt
/// die Abteilung am Leerzeichen — ein Kürzel wie `C 03o` zerfiele in der
/// Zerlegung auf beiden Seiten still. Deshalb [normalisiere] beim Einlesen.
abstract final class AbteilungKuerzel {
  static const String _praefix = 'C0';

  /// Entfernt sämtliche Leerzeichen (`C 03o` → `C03o`).
  static String normalisiere(String? abteilung) =>
      (abteilung ?? '').replaceAll(RegExp(r'\s+'), '');

  /// Setzt die Abteilung aus Haupt- und optionalem Nebensachgebiet zusammen:
  /// `C05` + `C03` → `C05/3`. Ohne Nebensachgebiet bleibt es beim Hauptkürzel.
  static String setzeZusammen(String hauptKuerzel, String? nebenKuerzel) {
    final haupt = normalisiere(hauptKuerzel);
    final neben = normalisiere(nebenKuerzel);
    if (neben.isEmpty) return haupt;
    return '$haupt/${nebenteil(neben)}';
  }

  /// Das Kürzel ohne das Präfix `C0` — der Nebenteil in der Schreibweise der
  /// Kanzlei. Ein Kürzel ohne dieses Präfix bleibt unverändert (Notnagel für
  /// künftige, über die Pflege angelegte Kürzel außerhalb des Schemas).
  static String nebenteil(String kuerzel) {
    final bereinigt = normalisiere(kuerzel);
    return bereinigt.startsWith(_praefix)
        ? bereinigt.substring(_praefix.length)
        : bereinigt;
  }

  /// Rückabbildung des Nebenteils auf sein Kürzel (`3o` → `C03o`).
  static String nebenteilZuKuerzel(String nebenteil) {
    final bereinigt = normalisiere(nebenteil);
    return bereinigt.isEmpty ? '' : '$_praefix$bereinigt';
  }

  /// Zerlegt eine gespeicherte Abteilung in Haupt- und Nebenkürzel
  /// (`C05/3` → `C05` + `C03`). Ohne Schrägstrich ist alles Hauptkürzel.
  static ({String haupt, String? neben}) zerlege(String? abteilung) {
    final bereinigt = normalisiere(abteilung);
    final trenner = bereinigt.indexOf('/');
    if (trenner < 0) return (haupt: bereinigt, neben: null);
    final nebenRoh = bereinigt.substring(trenner + 1);
    return (
      haupt: bereinigt.substring(0, trenner),
      neben: nebenRoh.isEmpty ? null : nebenteilZuKuerzel(nebenRoh),
    );
  }
}
