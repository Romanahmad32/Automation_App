/// Überführt ein Kfz-Kennzeichen in die Domänen-Konvention
/// „Unterscheidungszeichen-Erkennungsbuchstaben Nummer" (z. B. „HG-E 1427").
/// Spiegelt `ZentralrufReplyParser.NormalizeKennzeichen` im Backend, damit
/// Vergleiche (z. B. Fallback-Zuordnung einer Antwort über das
/// Gegner-Kennzeichen) tolerant gegenüber Schreibvarianten sind.
/// Nicht erkennbare Schreibweisen bleiben (bereinigt) unverändert.
String? normalizeKennzeichen(String? kennzeichen) {
  if (kennzeichen == null || kennzeichen.trim().isEmpty) return kennzeichen;

  final bereinigt = kennzeichen.replaceAll(RegExp(r'\s+'), ' ').trim();
  final match = RegExp(
    r'^([A-ZÄÖÜ]{1,3})[ \-]?([A-ZÄÖÜ]{1,2})[ \-]?(\d{1,4})\s*([HE])?$',
  ).firstMatch(bereinigt.toUpperCase());
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
