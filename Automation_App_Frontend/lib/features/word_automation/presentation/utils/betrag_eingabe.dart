/// Lesen und Schreiben deutscher Betragseingaben — eine Stelle für beide
/// Richtungen, verwendet von der Schadensaufstellung im Wizard und vom
/// Standardpositionen-Editor in den Einstellungen. Zwei Abschriften hätten
/// irgendwann zwei Meinungen dazu, was `1.250,5` bedeutet.
library;

/// Eine Zahl, deren Punkte alle Tausendertrennzeichen sein **können**: vor dem
/// ersten Punkt ein bis drei Ziffern, dahinter lauter Dreiergruppen.
///
/// Die führende Ziffer darf keine `0` sein, und das ist kein Schönheitsfehler:
/// `0.500` als 500 zu lesen wäre genau der Fehler, den diese Regel abstellen
/// soll — 500 € schreibt niemand mit führender Null, `0.50` als Tippweise für
/// fünfzig Cent dagegen kommt vor.
final RegExp tausendergliederung = RegExp(r'^[-+]?[1-9]\d{0,2}(\.\d{3})+$');

/// Übersetzt eine deutsche Betragseingabe in die Schreibweise, die
/// [double.tryParse] versteht — und **nur** das: Was mehrdeutig ist, kommt hier
/// so heraus, dass `tryParse` daran scheitert. Geraten wird nicht.
///
/// Der Punkt ist der ganze Grund für diese Funktion. Er ist im Deutschen
/// Tausendertrennzeichen (`1.500` = eintausendfünfhundert), auf dem
/// Ziffernblock und in kopierten Rechnungsbeträgen aber genauso oft ein
/// Dezimaltrennzeichen (`1.5` = eins fünfzig). Die frühere Fassung strich jeden
/// Punkt und machte damit aus `1.5` kommentarlos **15,00 €**.
String dezimalpunktSchreibweise(String roh) {
  // Ein Komma hat die Dezimalrolle schon vergeben; daneben kann ein Punkt nur
  // noch Tausendertrennzeichen sein. `2.560,87` und `1.234.567,89` — aber auch
  // `1.234,56 €`, das mit dem Währungszeichen unlesbar bleibt und bleiben soll.
  if (roh.contains(',')) {
    return roh.replaceAll('.', '').replaceAll(',', '.');
  }
  // Ohne Komma entscheidet die Form: Nur eine saubere Dreiergliederung ist eine
  // Tausendertrennung.
  if (tausendergliederung.hasMatch(roh)) return roh.replaceAll('.', '');
  // Sonst ist der Punkt das Dezimaltrennzeichen — so, wie ihn `double.tryParse`
  // ohnehin liest. `1.5` wird 1,50, `1234.56` wird 1234,56. Und `1.234.56`, wo
  // beides zugleich behauptet wird, scheitert: Das ist die gewollte Antwort auf
  // eine Eingabe, die zwei Bedeutungen zulässt.
  return roh;
}

/// Der Betrag hinter einer Eingabe, oder `null`, wenn nichts Eindeutiges
/// dasteht. Ein `null` heißt „nicht lesbar" und nie „egal": Wer damit weiter
/// rechnet, muss die Zeile beanstanden (`schadenspositionen_pruefung.dart`).
///
/// `-0,0` wird zu `0.0` normalisiert: Es ist numerisch null, gilt also nicht
/// als negativ (`-0.0 < 0` ist `false`) — würde aber als `-0.0` im JSON an das
/// Backend hinausgehen und der Zusage „kein negativer Betrag" wörtlich
/// widersprechen.
double? betragAusEingabe(String text) {
  final wert = double.tryParse(dezimalpunktSchreibweise(text.trim()));
  if (wert == 0) return 0.0;
  return wert;
}

/// Der Satz an der Zeile, wenn ein Betrag nicht zu lesen ist. Er nennt, was
/// dort steht: „ungültig" allein ließe den Anwalt raten, welches Zeichen stört
/// — bei `1.234,56 €` ist es das Währungszeichen und sonst nichts.
///
/// Lange Eingaben werden gekürzt, damit die Meldung unter dem Feld die Zeile
/// nicht auseinanderzieht.
String unlesbarerBetragHinweis(String text) {
  final gezeigt = text.trim();
  final kurz = gezeigt.length > 20 ? '${gezeigt.substring(0, 20)}…' : gezeigt;
  return 'Betrag „$kurz" nicht lesbar';
}

/// Zahl als deutsche Eingabe formatieren (Komma, ohne überflüssige Nullen).
String betragAlsEingabe(double value) {
  var text = value.toStringAsFixed(2).replaceAll('.', ',');
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith(',')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
