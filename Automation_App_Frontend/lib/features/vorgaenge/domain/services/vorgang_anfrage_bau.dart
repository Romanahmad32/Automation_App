import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Baut den Vorgang für [VorgangCubit.registriereAnfrage] — ausgelagert aus
/// dem Cubit, damit dieser unter der Dateilängengrenze bleibt (CLAUDE.md).
///
/// Ein erneutes Speichern (gleiche Referenz erneut angefragt) darf bereits
/// erfasste Antwort-/Dokumentdaten nicht verlieren: Ein bestehender Vorgang
/// wird über `copyWith` aktualisiert (das die unberührten Felder
/// durchreicht), ein neuer über `Vorgang.ausAnfrage` angelegt.
class VorgangAnfrageBau {
  static Vorgang aus({
    required Vorgang? bestehend,
    required String referenz,
    String rechtsgebiet = RechtsgebietWert.verkehrsrecht,
    int? mandantId,
    String? mandantName,
    String? unfallDatum,
    String? geschaedigtenKennzeichen,
    String? unfallort,
    String? unfalluhrzeit,
    String? polizeiVorgangsnummer,
  }) {
    if (bestehend == null) {
      return Vorgang.ausAnfrage(
        referenz: referenz,
        angefragtAm: DateTime.now(),
        rechtsgebiet: rechtsgebiet,
        mandantId: mandantId,
        mandantName: mandantName,
        unfallDatum: unfallDatum,
        geschaedigtenKennzeichen: geschaedigtenKennzeichen,
        unfallort: unfallort,
        unfalluhrzeit: unfalluhrzeit,
        polizeiVorgangsnummer: polizeiVorgangsnummer,
      );
    }
    return bestehend.copyWith(
      rechtsgebiet: rechtsgebiet,
      mandantId: mandantId,
      mandantName: mandantName,
      unfallDatum: unfallDatum,
      geschaedigtenKennzeichen: geschaedigtenKennzeichen,
      unfallort: unfallort,
      unfalluhrzeit: unfalluhrzeit,
      polizeiVorgangsnummer: polizeiVorgangsnummer,
    );
  }
}
