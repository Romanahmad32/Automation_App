import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/kennzeichen_normalisierung.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Fallback für die Antwort-Zuordnung, wenn die Referenz zu keinem Vorgang
/// passt (z. B. in der Mail verstümmelt): sucht unter den angefragten
/// [vorgaenge]n nach Gegner-Kennzeichen + Unfalldatum der Antwort. Liefert nur
/// einen eindeutigen Treffer — die Zuordnung bleibt eine „wahrscheinliche",
/// die der Anwalt im Formular bestätigt (Human-in-the-loop).
Vorgang? findeWahrscheinlichenVorgang(
  List<Vorgang> vorgaenge,
  ZentralrufReplyData data,
) {
  // Passt die Referenz exakt, ist keine Vermutung nötig.
  final referenz = data.referenz?.trim() ?? '';
  if (referenz.isNotEmpty &&
      vorgaenge.any((v) => Vorgang.gleicheReferenz(v.referenz, referenz))) {
    return null;
  }

  final unfallDatum = data.unfallDatum?.trim();
  if (unfallDatum == null || unfallDatum.isEmpty) return null;

  final kandidaten = vorgaenge
      .where(
        (vorgang) =>
            vorgang.status == VorgangStatus.angefragt &&
            gleichesKennzeichen(vorgang.kennzeichen, data.kennzeichen) &&
            vorgang.unfallDatum?.trim() == unfallDatum,
      )
      .toList();
  return kandidaten.length == 1 ? kandidaten.single : null;
}
