import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';

/// Welche Vollmachtsvorlage zu einem Vorgang passt (§4.11, Katalog §7.1).
///
/// Maßgeblich ist das **Rechtsgebiet**, nicht die Abteilung: Wer das
/// Rechtsgebiet von Hand abweichend gesetzt hat, meint damit die Sache — und
/// die bestimmt die Vorlage. Das Rechtsgebiet wird über den Katalog auf sein
/// Kürzel zurückgeführt; nur wenn der Katalog es nicht kennt (Altbestand,
/// Katalog nicht geladen), zählt die Abteilung.
///
/// `null` heißt „keine Vorbelegung, der Anwalt wählt" — nie ein stiller
/// Rückfall auf Unfallsachen, den Schwerpunkt der Kanzlei.
abstract final class VollmachtArtAbleitung {
  /// Die Vorlagenart zu einem Hauptkürzel des Katalogs.
  static VollmachtArt? zuKuerzel(String? kuerzel) =>
      switch (AbteilungKuerzel.zerlege(kuerzel).haupt) {
        'C03' => VollmachtArt.unfallsachen,
        'C03o' => VollmachtArt.bussgeldsachen,
        'C04' || 'C05' => VollmachtArt.strafsache,
        _ => null,
      };

  /// Die Vorlagenart zum Vorgang aus [rechtsgebiet] (über [katalog]) oder,
  /// wenn der Katalog das Rechtsgebiet nicht kennt, aus [abteilung].
  ///
  /// Nennen mehrere Katalogzeilen dasselbe Rechtsgebiet und führen sie zu
  /// verschiedenen Vorlagen, wird nicht geraten: `null`.
  static VollmachtArt? zuVorgang(
    List<Sachgebiet> katalog, {
    required String rechtsgebiet,
    String? abteilung,
  }) {
    final treffer = [
      for (final eintrag in katalog)
        if (RechtsgebietWert.normalisiert(rechtsgebiet).isNotEmpty &&
            RechtsgebietWert.gleich(
              eintrag.rechtsgebietVorschlag,
              rechtsgebiet,
            ))
          eintrag,
    ];
    if (treffer.isEmpty) return zuKuerzel(abteilung);

    final arten = {for (final eintrag in treffer) zuKuerzel(eintrag.kuerzel)};
    return arten.length == 1 ? arten.single : null;
  }
}
