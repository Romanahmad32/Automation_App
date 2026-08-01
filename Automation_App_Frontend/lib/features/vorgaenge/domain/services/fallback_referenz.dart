import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Liefert eine unter [vorgaenge] noch freie Ersatz-Referenz für eine
/// Zentralruf-Antwort, die keine Referenz trägt: „(ohne Referenz)",
/// „(ohne Referenz 2)", „(ohne Referenz 3)", …
///
/// Die Eindeutigkeit ist nötig, weil die Referenz der fachliche Schlüssel des
/// Vorgangs ist (Upsert pro Referenz): Ohne sie würde die zweite referenzlose
/// Antwort die erste stillschweigend überschreiben.
String freieOhneReferenz(List<Vorgang> vorgaenge) {
  String kandidat(int nummer) =>
      nummer == 1 ? '(ohne Referenz)' : '(ohne Referenz $nummer)';

  bool vergeben(String referenz) => vorgaenge.any(
        (vorgang) => Vorgang.gleicheReferenz(vorgang.referenz, referenz),
      );

  var nummer = 1;
  while (vergeben(kandidat(nummer))) {
    nummer++;
  }
  return kandidat(nummer);
}
