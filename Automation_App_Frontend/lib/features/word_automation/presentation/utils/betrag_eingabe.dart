/// Lesen und Schreiben deutscher Betragseingaben — eine Stelle für beide
/// Richtungen, verwendet von der Schadensaufstellung im Wizard und vom
/// Standardpositionen-Editor in den Einstellungen. Zwei Abschriften hätten
/// irgendwann zwei Meinungen dazu, was `1.250,5` bedeutet.
library;

/// `-0,0` wird zu `0.0` normalisiert: Es ist numerisch null, gilt also nicht
/// als negativ (`-0.0 < 0` ist `false`) — würde aber als `-0.0` im JSON an das
/// Backend hinausgehen und der Zusage „kein negativer Betrag" wörtlich
/// widersprechen.
double? betragAusEingabe(String text) {
  final wert = double.tryParse(
    text.trim().replaceAll('.', '').replaceAll(',', '.'),
  );
  if (wert == 0) return 0.0;
  return wert;
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
