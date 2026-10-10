import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Belegt den Kopf einer Vollmacht aus dem vor, was die App schon weiß
/// (§4.11, §1.3 „keine Doppelerfassung"): Mandant aus dem Register,
/// Unfalldatum vom Vorgang, „in Sachen" und „wegen" je Vorlagenart.
///
/// | Art | „in Sachen" | „wegen" |
/// |---|---|---|
/// | Unfallsachen | leer | Schadensersatz nach Verkehrsunfall vom *Unfalldatum* |
/// | Bußgeldsachen | Bußgeldsache *Name* | Vorwurf der OWi. am *(Tatdatum offen)* |
/// | Strafsache | leer | Strafverfahren gegen *Name* |
///
/// Das Tatdatum der Bußgeldsache kennt die App nicht; die Stelle bleibt im
/// vorbelegten Text offen, statt ein Datum zu erfinden.
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
        VollmachtArt.bussgeldsachen => 'Bußgeldsache ${kopf.name}'.trim(),
        _ => '',
      };

  /// Vorbelegung von „wegen" für [art] aus [kopf].
  static String wegen(VollmachtArt? art, VollmachtKopfdaten kopf) =>
      switch (art) {
        VollmachtArt.unfallsachen =>
          'Schadensersatz nach Verkehrsunfall vom ${kopf.unfalldatum.trim()}'
              .trim(),
        VollmachtArt.bussgeldsachen => 'Vorwurf der OWi. am ',
        VollmachtArt.strafsache => 'Strafverfahren gegen ${kopf.name}'.trim(),
        null => '',
      };

  /// Zieht „in Sachen" und „wegen" nach, wenn sich Art oder Kopfdaten ändern —
  /// aber **nur, solange der Anwalt sie nicht selbst geändert hat** (§1.3:
  /// nichts still überschreiben). Unberührt heißt: Der Text ist noch genau
  /// die Vorbelegung zum vorigen Stand ([altArt], [alt]).
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
