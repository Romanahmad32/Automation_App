/// Die Schreiblinie, die auf dem Papier für einen fehlenden Wert steht
/// (§4.11, #171): Unterstriche, auf denen der Mandant von Hand ergänzt.
///
/// Zwei Seiten zeichnen sie. Die Mandantenfelder setzt der Dienst selbst als
/// Linie ein — das Gegenstück gleichen Namens im Slice `Vollmacht` des
/// Dienstes, dort stehen auch deren Längen; das Frontend schickt leere Werte
/// leer. Hier stehen nur die Linien, die das Frontend in die Vorbelegung von
/// „in Sachen" und „wegen" schreibt: Diese Texte entstehen hier, und nur so
/// zeigen Feld, Vorschau und Papier dasselbe. Die Namenslinie ist so lang
/// wie dort die eines ganz leeren Namens.
abstract final class VollmachtSchreiblinie {
  static const String zeichen = '_';

  /// Für ein fehlendes Datum (Unfall- oder Tatdatum) in „wegen".
  static const int datum = 12;

  /// Für einen fehlenden Mandantennamen in „in Sachen" und „wegen".
  static const int name = 32;

  /// Eine Linie aus [laenge] Zeichen.
  static String linie(int laenge) => zeichen * laenge;

  /// [wert] ohne Rand — oder, wenn er leer ist, eine Linie aus [laenge]
  /// Zeichen.
  static String oder(String wert, int laenge) {
    final getrimmt = wert.trim();
    return getrimmt.isEmpty ? linie(laenge) : getrimmt;
  }
}
