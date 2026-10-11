import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_feld.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_feldauswahl.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';

/// Welche Kopffelder der Dialog zum aktuellen Stand zeigt und welche davon
/// auf dem Papier frei bleiben (#171) — die Felder und die Zeile über den
/// Knöpfen fragen hier, damit beide dasselbe sagen. Die Regeln stehen in
/// `VollmachtFeldauswahl`.
extension VollmachtStandFelder on VollmachtStand {
  /// Die Vorlage zur gewählten Art; null ohne Art oder ohne Vorlagenstand.
  VollmachtVorlage? get vorlage {
    final gewaehlt = art;
    return gewaehlt == null ? null : vorlagen?.zu(gewaehlt);
  }

  Set<VollmachtFeld> get sichtbareFelder =>
      VollmachtFeldauswahl.sichtbar(art, vorlage);

  List<VollmachtFeld> get freiBleibendeFelder =>
      VollmachtFeldauswahl.freiBleibend(art, vorlage, kopfdaten);
}
