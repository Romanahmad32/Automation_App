import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';

/// Liest aus einem Akten-Ordnernamen das Aktentyp-Präfix heraus: welcher
/// [Aktentyp] es ist und welche Zeichen davon stammen. Beides aus **einer**
/// Tabelle — die Zuordnungsliste filtert danach, der Namensvorschlag streift
/// dasselbe Präfix ab (`nameVorschlagAusOrdner`). Zwei getrennte Listen wären
/// beim nächsten gefundenen Schreibfehler auseinandergelaufen.
///
/// Die Schreibweisen sind die in der Kanzlei tatsächlich beobachteten,
/// uneinheitlichen; ein unbekannter Ordnername ist [Aktentyp.ohnePraefix] und
/// bleibt damit sichtbar.
class AktentypErkennung {
  const AktentypErkennung._();

  /// Präfix → Aktentyp. Reihenfolge egal: beim Erkennen gewinnt das
  /// **längste** passende Präfix. So verdeckt kein kurzer Eintrag einen
  /// längeren, der zufällig damit anfängt.
  static const Map<String, Aktentyp> praefixe = {
    'VUnvallursache': Aktentyp.verkehrsunfall,
    'VUnfallursache': Aktentyp.verkehrsunfall,
    'VerkUnfursache': Aktentyp.verkehrsunfall,
    'Verkehrsunfallsache': Aktentyp.verkehrsunfall,
    'Bußgeldsache': Aktentyp.bussgeld,
    'Bussgeldsache': Aktentyp.bussgeld,
    'BSsache': Aktentyp.bussgeld,
    'Owi': Aktentyp.bussgeld,
    'Strafsache': Aktentyp.straf,
    'StrSache': Aktentyp.straf,
    'FamSache': Aktentyp.familie,
    'Familiensache': Aktentyp.familie,
  };

  /// Der erkannte Typ und das dazugehörige Präfix in der Schreibweise der
  /// Tabelle. Ohne Treffer: [Aktentyp.ohnePraefix] und leeres Präfix.
  static ({Aktentyp typ, String praefix}) erkenne(String ordnername) {
    final name = ordnername.trim().toLowerCase();
    var treffer = '';
    var typ = Aktentyp.ohnePraefix;
    for (final eintrag in praefixe.entries) {
      final praefix = eintrag.key;
      if (praefix.length <= treffer.length) continue;
      if (name.startsWith(praefix.toLowerCase())) {
        treffer = praefix;
        typ = eintrag.value;
      }
    }
    return (typ: typ, praefix: treffer);
  }

  /// Kurzform, wenn nur der Typ zählt (Filter, Gruppierung).
  static Aktentyp typVon(String ordnername) => erkenne(ordnername).typ;
}
