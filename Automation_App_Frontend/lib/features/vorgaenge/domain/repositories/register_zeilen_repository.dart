import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';

/// Port für die Zeilen der Registeransicht (§6.2) — laufende Vorgänge und
/// übernommene Historie in **einer** Folge.
///
/// Gebaut werden sie im Backend (`RegisterZeilenBau`), nicht hier: Nur dort
/// liegen beide Quellen nebeneinander, und nur so sagen Bildschirm und
/// Word-/PDF-Spiegel per Konstruktion dasselbe. Vorher rechnete die Ansicht
/// ihre Zellen selbst aus den Vorgängen — zwei Quellen, deren Auseinanderlaufen
/// niemandem auffiel (Issue #109).
abstract class RegisterZeilenRepository {
  /// Alle Zeilen; mit [jahrgang] nur die eines Jahres. Laufende Vorgänge sind
  /// eingeschlossen — der Filter „nur abgeschlossene" gilt für die
  /// Spiegeldatei, nicht für den Bildschirm.
  Future<List<RegisterZeile>> ladeZeilen({int? jahrgang});
}
