/// Wie ein Zeitpunkt der Sicherungsablage in einem Satz steht (§7.2).
///
/// „heute um 14:12" statt „01.09.2026 um 14:12": Beim Start geht es um die
/// Frage, ob der andere Arbeitsplatz *gerade eben* dran war oder vor Wochen —
/// und ein Datum muss man dafür erst mit dem heutigen vergleichen.
abstract final class SicherungsZeitpunkt {
  /// [jetzt] ist da, damit der Test nicht vom Kalender des Rechners abhängt.
  static String beschreibe(DateTime wann, {DateTime? jetzt}) {
    final heute = jetzt ?? DateTime.now();
    final tage = _tag(heute).difference(_tag(wann)).inDays;
    return switch (tage) {
      0 => 'heute um ${uhrzeit(wann)}',
      1 => 'gestern um ${uhrzeit(wann)}',
      _ => 'am ${datum(wann)} um ${uhrzeit(wann)}',
    };
  }

  /// „01.09.2026"
  static String datum(DateTime wann) =>
      '${_zwei(wann.day)}.${_zwei(wann.month)}.${wann.year}';

  /// „14:12"
  static String uhrzeit(DateTime wann) =>
      '${_zwei(wann.hour)}:${_zwei(wann.minute)}';

  static DateTime _tag(DateTime wann) =>
      DateTime(wann.year, wann.month, wann.day);

  static String _zwei(int wert) => wert.toString().padLeft(2, '0');
}
