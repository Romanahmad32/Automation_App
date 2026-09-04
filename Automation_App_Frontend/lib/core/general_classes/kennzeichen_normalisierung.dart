/// Erkennbare Schreibweisen eines Kfz-Kennzeichens: Unterscheidungszeichen,
/// Erkennungsbuchstaben, Nummer — die Trenner dazwischen sind frei (Bindestrich,
/// Leerzeichen oder nichts), dazu optional das E/H-Suffix für Elektro- und
/// Oldtimerkennzeichen.
///
/// Bewusst tolerant: Hier geht es ums *Wiedererkennen* eines Werts, nicht um
/// die Eingabeform. Wer die Konvention braucht, lässt sich den Wert von
/// [normalizeKennzeichen] geben — und genau so hält es `KennzeichenField`, das
/// jedes Kennzeichenfeld der App baut: prüfen, was lesbar ist, und die
/// Schreibweise selbst herstellen, statt sie zu verlangen.
final _kennzeichenMuster = RegExp(
  r'^([A-ZÄÖÜ]{1,3})[ \-]?([A-ZÄÖÜ]{1,2})[ \-]?(\d{1,4})\s*([HE])?$',
);

final _mehrfachLeerraum = RegExp(r'\s+');

/// Überführt ein Kfz-Kennzeichen in die Domänen-Konvention
/// „Unterscheidungszeichen-Erkennungsbuchstaben Nummer" (z. B. „HG-E 1427").
/// Spiegelt `ZentralrufReplyParser.NormalizeKennzeichen` im Backend, damit
/// Vergleiche (z. B. Fallback-Zuordnung einer Antwort über das
/// Gegner-Kennzeichen) tolerant gegenüber Schreibvarianten sind.
/// Nicht erkennbare Schreibweisen bleiben (bereinigt) unverändert.
String? normalizeKennzeichen(String? kennzeichen) {
  if (kennzeichen == null || kennzeichen.trim().isEmpty) return kennzeichen;

  final bereinigt = kennzeichen.replaceAll(_mehrfachLeerraum, ' ').trim();
  final match = _kennzeichenMuster.firstMatch(bereinigt.toUpperCase());
  if (match == null) return bereinigt;

  final suffix = match.group(4) ?? '';
  return '${match.group(1)}-${match.group(2)} ${match.group(3)}$suffix';
}

/// True, wenn beide Kennzeichen vorhanden sind und normalisiert übereinstimmen.
bool gleichesKennzeichen(String? a, String? b) {
  final na = normalizeKennzeichen(a);
  final nb = normalizeKennzeichen(b);
  if (na == null || na.isEmpty || nb == null || nb.isEmpty) return false;
  return na == nb;
}

/// Ob [wert] als Kfz-Kennzeichen lesbar ist — genau das, was
/// [normalizeKennzeichen] in die Konvention überführen kann. Leer und `null`
/// sind **kein** Kennzeichen; ob ein leeres Feld erlaubt ist, entscheidet der
/// Pflicht-Validator daneben und nicht diese Frage.
bool istKennzeichen(String? wert) {
  if (wert == null || wert.trim().isEmpty) return false;
  final bereinigt = wert.replaceAll(_mehrfachLeerraum, ' ').trim();
  return _kennzeichenMuster.hasMatch(bereinigt.toUpperCase());
}
