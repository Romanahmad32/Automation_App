import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';

/// Das Rechtsgebiet eines Vorgangs aus seiner Abteilung (§7.1).
///
/// Abteilung und Rechtsgebiet benennen dieselbe Katalogzeile — die eine über
/// ihr Kürzel (`C03`), das andere über ihren Anzeigenamen („Verkehrsrecht").
/// Erfasst wird deshalb nur die Abteilung; das Rechtsgebiet folgt ihr.
///
/// Maßgeblich ist das **Hauptsachgebiet**: `C05/3` ist Strafrecht mit
/// Verkehrsbezug und gehört im Register (§6.2) in die Zeile „Strafrecht".
///
/// Der Katalog trägt den Namen dieser Ableitung schon im Feld
/// [Sachgebiet.rechtsgebietVorschlag] — ein *Vorschlag*, kein Zwang: Wer das
/// Rechtsgebiet von Hand setzt, dessen Wahl bleibt stehen. Das zu entscheiden
/// ist Sache der Oberfläche, nicht dieser Funktion.
abstract final class RechtsgebietAbleitung {
  /// Der Rechtsgebiets-Vorschlag zur Abteilung [abteilung], oder `null`, wenn
  /// sich keiner bilden lässt: leere Abteilung, oder ein Kürzel, das der
  /// Katalog nicht kennt (Altbestand, Tippfehler). `null` heißt „nichts
  /// vorzuschlagen" — nie „Verkehrsrecht": Ein stillschweigender Rückfall auf
  /// den Schwerpunkt der Kanzlei wäre genau die falsche Zeile im Register.
  static String? zuAbteilung(List<Sachgebiet> katalog, String? abteilung) {
    final haupt = AbteilungKuerzel.zerlege(abteilung).haupt;
    if (haupt.isEmpty) return null;
    for (final sachgebiet in katalog) {
      if (sachgebiet.kuerzel == haupt) return sachgebiet.rechtsgebietVorschlag;
    }
    return null;
  }
}
