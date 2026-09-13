/// Bytes in einer Einheit, die ein Mensch liest — mit deutschem
/// Dezimaltrenner (`2,4 MB`), wie es die übrige Oberfläche für Zahlen mit
/// Nachkommastelle hält (`rvg_details.dart`, `betrag_eingabe.dart`).
///
/// Eine Stelle für beide Seiten, die Dateigrößen zeigen:
/// `AnhangDarstellung.alsGroesse` (`email_versand`) und `PosteingangAnhangZeile`
/// (`mailbox`) rufen sie beide statt je eine eigene Fassung zu pflegen.
String formatiereDateigroesse(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes < kb) return '$bytes Bytes';
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  if (bytes < gb) {
    return '${(bytes / mb).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} GB';
}
