import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_feld.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';

/// Welche Kopffelder der Vollmacht-Dialog zeigt und welche davon auf dem
/// Papier frei bleiben (§4.11, #171).
///
/// **Gezeigt wird, was auf der Vorlage steht.** Ein Feld erscheint, wenn
/// einer seiner Platzhalter ([VollmachtFeld.platzhalter]) in der gewählten
/// Vorlage vorkommt — mit den Vorlagen der Kanzlei stehen Telefon und E-Mail
/// damit nur bei Unfallsachen, deren Fußblock sie trägt. Ist die Vorlage
/// unbekannt (kein Vorlagenstand, keine Art, `platzhalter == null`), zeigt
/// der Dialog alle Felder: Ein Feld zu viel kostet einen Blick, eines zu
/// wenig einen Wert auf dem Papier, den niemand eintragen konnte. Unabhängig
/// davon gehört das Unfalldatum nur zu Unfallsachen, das Tatdatum nur zu
/// Bußgeldsachen — sie speisen „wegen" nur in dieser Art.
///
/// **Frei bleibt, was als Linie gedruckt wird** — ein Hinweis, keine Sperre
/// (§4.11 „vorbelegt, nicht vorgeschrieben").
abstract final class VollmachtFeldauswahl {
  /// Die Felder, die der Dialog zu [art] mit [vorlage] zeigt, in der
  /// Reihenfolge des Formulars.
  static Set<VollmachtFeld> sichtbar(
    VollmachtArt? art,
    VollmachtVorlage? vorlage,
  ) {
    final inVorlage = {
      for (final name in vorlage?.platzhalter ?? const <String>[])
        name.toLowerCase(),
    };
    final unbekannt = vorlage?.platzhalter == null;
    return {
      for (final feld in VollmachtFeld.values)
        if (_gehoertZurArt(feld, art) &&
            (unbekannt ||
                feld.platzhalter.any(
                  (name) => inVorlage.contains(name.toLowerCase()),
                )))
          feld,
    };
  }

  /// Die gezeigten Felder, die mit [kopf] auf dem Papier zum Ausfüllen frei
  /// bleiben, in der Reihenfolge des Formulars.
  static List<VollmachtFeld> freiBleibend(
    VollmachtArt? art,
    VollmachtVorlage? vorlage,
    VollmachtKopfdaten kopf,
  ) => [
    for (final feld in sichtbar(art, vorlage))
      if (bleibtFrei(feld, art, kopf, vorlage: vorlage)) feld,
  ];

  /// Ob [feld] mit [kopf] auf dem Papier frei bleibt — sofern es überhaupt
  /// gedruckt wird ([sichtbar]).
  ///
  /// Ein leeres Mandantenfeld druckt der Dienst als Linie. Ein leeres Datum
  /// steht als Linie in „wegen" — aber nur, solange „wegen" noch die
  /// Vorbelegung ist; hat der Anwalt den Text selbst geschrieben, speist das
  /// Datum nichts mehr. Ausnahme: Führt [vorlage] `{{Unfalldatum}}`, druckt
  /// der Dienst das leere Unfalldatum dort ohnehin als Linie. „in Sachen" und
  /// „wegen" selbst bleiben leer ohne Linie: Sie sind Sache des Anwalts, nicht
  /// des Mandanten.
  static bool bleibtFrei(
    VollmachtFeld feld,
    VollmachtArt? art,
    VollmachtKopfdaten kopf, {
    VollmachtVorlage? vorlage,
  }) {
    if (feld.wert(kopf).trim().isNotEmpty) return false;
    final wegenVorbelegt = kopf.wegen == VollmachtVorbelegung.wegen(art, kopf);
    return switch (feld) {
      VollmachtFeld.unfalldatum =>
        wegenVorbelegt || _fuehrt(vorlage, 'Unfalldatum'),
      VollmachtFeld.tatdatum => wegenVorbelegt,
      _ => feld.schreiblinie,
    };
  }

  static bool _fuehrt(VollmachtVorlage? vorlage, String platzhalter) =>
      vorlage?.platzhalter?.any(
        (name) => name.toLowerCase() == platzhalter.toLowerCase(),
      ) ??
      false;

  static bool _gehoertZurArt(VollmachtFeld feld, VollmachtArt? art) =>
      switch (feld) {
        VollmachtFeld.unfalldatum => art == VollmachtArt.unfallsachen,
        VollmachtFeld.tatdatum => art == VollmachtArt.bussgeldsachen,
        _ => true,
      };
}
