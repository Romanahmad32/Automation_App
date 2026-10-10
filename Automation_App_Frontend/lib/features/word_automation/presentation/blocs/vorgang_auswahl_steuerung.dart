import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Der Mandantenabgleich zur Vorgangsauswahl — ausgelagert aus `WizardCubit`
/// (`wizard_cubit.dart`), weil der sonst über seine Längengrenze liefe (siehe
/// `EntwurfSicherungSteuerung` für dasselbe Muster).
///
/// Reine Nachschlagehilfe: Sie hält nur den UseCase, keinen eigenen
/// veränderlichen Zustand. `WizardCubit.selectVorgang` entscheidet selbst, wann
/// sie gebraucht wird — `emit`, `isClosed` und der Abgleich gegen den
/// inzwischen aktuellen Zustand bleiben dort, das sind Cubit-eigene Zugriffe,
/// die diese Klasse nicht hat.
class VorgangAuswahlSteuerung {
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  VorgangAuswahlSteuerung(this._getMandanten);

  /// Ob [alt] und [neu] denselben Vorgang meinen — Referenzvergleich
  /// (`Vorgang.gleicheReferenz`), nicht Objektidentität (#133):
  /// `vorgang_selector.dart` reicht Vorgänge aus der geladenen Liste und aus
  /// dem Vorauswahl-Vorschlag durch, und nach jedem Neuladen sind das neue
  /// Instanzen derselben Sache.
  static bool istGleicherVorgang(Vorgang? alt, Vorgang? neu) =>
      alt != null &&
      neu != null &&
      Vorgang.gleicheReferenz(alt.referenz, neu.referenz);

  /// Ob sich der zugeordnete Mandant geändert hat, obwohl der Vorgang
  /// derselbe blieb — etwa weil Tab 1 den Vorgang inzwischen einem anderen
  /// Mandanten zugeordnet hat. §1.3: lieber leer als falsch (Review-
  /// Nachbesserung #154 zu #133, Befund 2) — der bisherige Frühausstieg ließ
  /// `WizardState.selectedMandant` in diesem Fall auf dem alten Stand stehen.
  static bool mandantHatSichGeaendert(Vorgang? alt, Vorgang? neu) =>
      alt?.mandantId != neu?.mandantId;

  /// Sucht den Mandanten zu [mandantId] im Register nach — `null`, wenn keiner
  /// gefunden wird oder der Abruf scheitert. `mandantId == null` fragt gar
  /// nicht erst nach: ohne zugeordneten Mandanten gibt es nichts zu laden.
  Future<Mandant?> finde(int? mandantId) async {
    if (mandantId == null) return null;
    final result = await _getMandanten(const NoParams());
    switch (result) {
      case Right(value: final mandanten):
        for (final mandant in mandanten) {
          if (mandant.id == mandantId) return mandant;
        }
        return null;
      case Left():
        return null;
    }
  }
}
