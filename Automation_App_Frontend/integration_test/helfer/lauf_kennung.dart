import 'dart:math';

/// Eigene Namen und Kennzeichen je Lauf — damit ein Durchlauf auf demselben
/// Ausgangsbestand beliebig oft laufen kann, ohne aufzuräumen.
///
/// Der Dienst lehnt einen zweiten Mandanten gleichen Namens ab (409), und die
/// Referenz eines Vorgangs ist sein Schlüssel: Beides muss je Lauf neu sein.
/// Alles bleibt erfunden; Adressen enden auf `.invalid` (RFC 2606).
class LaufKennung {
  /// `MMddHHmmss` des Laufbeginns — eindeutig je Sekunde.
  final String zeitcode;

  /// Vierstellig, ohne führende Null — der Zahlteil der Kennzeichen.
  final int nummer;

  final DateTime beginn;

  const LaufKennung({
    required this.zeitcode,
    required this.nummer,
    required this.beginn,
  });

  factory LaufKennung.jetzt() {
    final jetzt = DateTime.now();
    String zwei(int wert) => wert.toString().padLeft(2, '0');
    return LaufKennung(
      zeitcode:
          '${zwei(jetzt.month)}${zwei(jetzt.day)}'
          '${zwei(jetzt.hour)}${zwei(jetzt.minute)}${zwei(jetzt.second)}',
      // Zufall statt Uhr: Die Uhr wiederholte sich alle 9000 s; so trifft ein
      // Wiederholungslauf auf demselben Datenordner nur mit 1:9000 dieselbe
      // Nummer (und die Sekunde im Zeitcode trennt die Namen ohnehin).
      nummer: 1000 + Random().nextInt(9000),
      beginn: jetzt,
    );
  }

  /// Ein Kennzeichen in der Konvention `HG-E 1427`; [kuerzel] trennt die
  /// Durchläufe voneinander, falls zwei in derselben Sekunde starten.
  String kennzeichen(String kuerzel) => 'E-$kuerzel $nummer';

  /// Unfalltag vierzehn Tage vor dem Lauf, deutsch geschrieben.
  String get unfalldatum {
    final tag = beginn.subtract(const Duration(days: 14));
    String zwei(int wert) => wert.toString().padLeft(2, '0');
    return '${zwei(tag.day)}.${zwei(tag.month)}.${tag.year}';
  }

  /// Ein Nachname, den es im Bestand noch nicht gibt.
  String nachname(String stamm) => '$stamm$zeitcode';

  String email(String stamm) => '${nachname(stamm).toLowerCase()}@e2e.invalid';
}
