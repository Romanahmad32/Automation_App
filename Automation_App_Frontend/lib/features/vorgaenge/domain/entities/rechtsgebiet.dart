/// Das Rechtsgebiet eines Vorgangs — die Sachgebiete-Spalte des
/// Auftragsregisters — ist ein **freier String**: gespeichert wird, was der
/// Anwalt gewählt hat, und die Auswahl kommt seit #70 aus dem
/// Sachgebietskatalog (§7.1, `GET /api/Sachgebiete`) statt aus einem Enum.
///
/// Das frühere Enum ist bewusst weg: Sein fester Wertesatz war die Quelle des
/// Fehlers, den der Katalog beseitigt (vier Katalog-Sachgebiete waren nicht
/// wählbar, `fromValue` bog Unbekanntes still auf Verkehrsrecht um). Übrig
/// bleiben die Regeln über dem String — Anzeige, Vergleich, Verkehrsrecht als
/// fachlicher Schwerpunkt.
///
/// Altbestand: Das Enum speicherte Kleinschreibungs-Schlüssel
/// (`verkehrsrecht`); der Katalog liefert Anzeigenamen (`Verkehrsrecht`).
/// Beide bleiben unverändert gespeichert und treffen sich in [normalisiert] —
/// **keine Datenmigration**.
abstract final class RechtsgebietWert {
  /// Der fachliche Schwerpunkt der Kanzlei und darum der Standardwert
  /// bei der Neuanlage.
  static const String verkehrsrecht = 'Verkehrsrecht';

  /// Platzhalter, wenn am Vorgang kein Rechtsgebiet steht. Muss zu
  /// `RechtsgebietAnzeige.Unbekannt` im Backend passen.
  static const String unbekannt = '—';

  /// Anzeigename des **gespeicherten** Werts — die vierte Registerspalte.
  ///
  /// Muss dieselbe Antwort geben wie `RechtsgebietAnzeige.Fuer` im Backend,
  /// sonst zeigt die Ansicht ein anderes Sachgebiet an, als in der
  /// Register-Datei steht. Ein nie erfasstes Sachgebiet steht in einem
  /// Sachgebiete-Register als [unbekannt] und nicht als „Verkehrsrecht".
  static String anzeige(String? gespeichert) {
    final roh = (gespeichert ?? '').trim();
    if (roh.isEmpty) return unbekannt;
    return roh[0].toUpperCase() + roh.substring(1);
  }

  /// Vergleichsform: getrimmt und kleingeschrieben. Hier treffen sich der
  /// Altbestand (`verkehrsrecht`) und die Katalognamen (`Verkehrsrecht`) —
  /// Filter und Fachregeln vergleichen nie die Rohwerte direkt.
  static String normalisiert(String? wert) => (wert ?? '').trim().toLowerCase();

  /// Ob zwei gespeicherte/gewählte Werte dasselbe Rechtsgebiet meinen.
  static bool gleich(String? a, String? b) =>
      normalisiert(a) == normalisiert(b);

  /// Ob der Wert Verkehrsrecht ist — schaltet die Unfall-/Zentralruf-Teile
  /// des Vorgangs frei (Pflichtfelder, Kennzeichen in der Referenz, §4.2).
  static bool istVerkehrsrecht(String? wert) => gleich(wert, verkehrsrecht);
}
