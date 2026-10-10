/// Der Betreff für die Antwort auf eine Posteingangsnachricht (§4.3): stellt
/// „AW: " voran, ohne ein vorhandenes Antwort-Kürzel zu verdoppeln.
///
/// Erkannt werden `AW:`, `Aw:`, `RE:` und `Re:` — ohne Rücksicht auf
/// Groß-/Kleinschreibung, denn Mailprogramme schreiben das Kürzel
/// unterschiedlich (der Zentralruf antwortet z. B. mit „Re:"). **Kein
/// Zitieren, kein Weiterleiten** (REQUIREMENTS §4.3, §8): Diese Funktion
/// rührt an nichts als der Betreffzeile — der Versanddialog übernimmt sie nur
/// als Vorgabe, die der Anwalt weiter ändern kann.
///
/// Reiner Dienst ohne Flutter, testbar ohne Widget — wie
/// `VorgangsbezugErkenner` daneben.
String antwortBetreff(String betreff) {
  final getrimmt = betreff.trim();
  final hatKuerzelSchon = RegExp(
    r'^(aw|re)\s*:',
    caseSensitive: false,
  ).hasMatch(getrimmt);
  return hatKuerzelSchon ? getrimmt : 'AW: $getrimmt';
}
