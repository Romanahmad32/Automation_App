/// Einheitliche Datums-/Zeitanzeige der Postfach-Ansicht (TT.MM.JJJJ HH:MM).
String formatMailboxDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}
