import 'package:automation_app/core/aktualisierung/neue_version.dart';

/// Ausgang der Update-Prüfung.
///
/// „Keine neuere Version" und „konnte nicht nachsehen" sind bewusst zwei
/// verschiedene Antworten. Beides als „Sie sind aktuell" zu zeigen, wäre eine
/// Falschaussage — der Anwalt würde sich auf eine Prüfung verlassen, die nie
/// stattgefunden hat.
class AktualisierungsErgebnis {
  const AktualisierungsErgebnis.aktuell() : neueVersion = null, geprueft = true;

  const AktualisierungsErgebnis.verfuegbar(NeueVersion this.neueVersion)
    : geprueft = true;

  const AktualisierungsErgebnis.nichtErreichbar()
    : neueVersion = null,
      geprueft = false;

  /// Nur gesetzt, wenn es tatsächlich etwas Neueres gibt.
  final NeueVersion? neueVersion;

  /// Ob GitHub überhaupt geantwortet hat.
  final bool geprueft;
}
