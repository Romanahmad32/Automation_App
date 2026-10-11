import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_schreiblinie.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Belegt den Kopf einer Vollmacht aus dem vor, was die App schon weiß
/// (§4.11, §1.3 „keine Doppelerfassung"): Mandant aus dem Register,
/// Unfalldatum vom Vorgang, „in Sachen" und „wegen" je Vorlagenart.
///
/// | Art | „in Sachen" | „wegen" |
/// |---|---|---|
/// | Unfallsachen | leer | Schadensersatz nach Verkehrsunfall vom *Unfalldatum* |
/// | Bußgeldsachen | Bußgeldsache *Name* | Vorwurf der OWi. am *Tatdatum* |
/// | Strafsache | leer | Strafverfahren gegen *Name* |
///
/// Fehlt ein Datum oder der Name, steht an seiner Stelle eine Schreiblinie
/// ([VollmachtSchreiblinie], #171) — so hängt keine Zeile auf „vom" oder „am"
/// aus, und der Mandant kann auf dem Papier ergänzen. Das Tatdatum kennt die
/// App nicht; der Anwalt trägt es im eigenen Feld ein, statt dass ein Datum
/// erfunden wird.
abstract final class VollmachtVorbelegung {
  /// Der vorbelegte Kopf. Ohne [mandant] bleiben die Mandantenfelder leer —
  /// geraten wird aus dem Namens-Schnappschuss am Vorgang nichts, der trägt
  /// keine Anschrift.
  static VollmachtKopfdaten fuer({
    required Vorgang vorgang,
    Mandant? mandant,
    VollmachtArt? art,
  }) {
    final basis = VollmachtKopfdaten(
      vorname: mandant?.vorname ?? '',
      nachname: mandant?.nachname ?? '',
      strasse: mandant?.strasseHausnummer ?? '',
      plz: mandant?.postleitzahl ?? '',
      ort: mandant?.ort ?? '',
      telefon: mandant?.telefonnummer ?? '',
      email: mandant?.emailAdresse ?? '',
      unfalldatum: (vorgang.unfallDatum ?? '').trim(),
    );
    return basis.copyWith(
      inSachen: inSachen(art, basis),
      wegen: wegen(art, basis),
    );
  }

  /// Vorbelegung von „in Sachen" für [art] aus [kopf].
  static String inSachen(VollmachtArt? art, VollmachtKopfdaten kopf) =>
      switch (art) {
        VollmachtArt.bussgeldsachen => 'Bußgeldsache ${_name(kopf)}',
        _ => '',
      };

  /// Vorbelegung von „wegen" für [art] aus [kopf].
  static String wegen(VollmachtArt? art, VollmachtKopfdaten kopf) =>
      switch (art) {
        VollmachtArt.unfallsachen =>
          'Schadensersatz nach Verkehrsunfall vom ${_datum(kopf.unfalldatum)}',
        VollmachtArt.bussgeldsachen =>
          'Vorwurf der OWi. am ${_datum(kopf.tatdatum)}',
        VollmachtArt.strafsache => 'Strafverfahren gegen ${_name(kopf)}',
        null => '',
      };

  static String _name(VollmachtKopfdaten kopf) =>
      VollmachtSchreiblinie.oder(kopf.name, VollmachtSchreiblinie.name);

  static String _datum(String datum) =>
      VollmachtSchreiblinie.oder(datum, VollmachtSchreiblinie.datum);

  /// Zieht „in Sachen" und „wegen" nach, wenn sich Art oder Kopfdaten ändern —
  /// aber **nur, solange der Anwalt sie nicht selbst geändert hat** (§1.3:
  /// nichts still überschreiben). Unberührt heißt: Der Text ist noch genau
  /// die Vorbelegung zum vorigen Stand ([altArt], [alt]) — samt Linie. Wer
  /// das Datum statt ins eigene Feld direkt über die Linie tippt, hat „wegen"
  /// damit geändert; das bleibt dann stehen.
  static VollmachtKopfdaten nachziehen({
    required VollmachtArt? altArt,
    required VollmachtKopfdaten alt,
    required VollmachtArt? neuArt,
    required VollmachtKopfdaten neu,
  }) {
    final inSachenUnberuehrt = neu.inSachen == inSachen(altArt, alt);
    final wegenUnberuehrt = neu.wegen == wegen(altArt, alt);
    return neu.copyWith(
      inSachen: inSachenUnberuehrt ? inSachen(neuArt, neu) : null,
      wegen: wegenUnberuehrt ? wegen(neuArt, neu) : null,
    );
  }
}
