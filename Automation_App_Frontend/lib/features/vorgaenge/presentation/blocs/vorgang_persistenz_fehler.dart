import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:equatable/equatable.dart';

/// Welche Persistenz-Operation eines Vorgangs fehlgeschlagen ist — bestimmt,
/// was „Erneut versuchen" wiederholt.
enum VorgangPersistenzAktion { laden, speichern, loeschen }

/// Ein fehlgeschlagener Schreib-/Ladevorgang der Vorgangs-Persistenz (§7.2:
/// erfasste Daten dürfen nicht stillschweigend verloren gehen). Trägt neben der
/// Meldung die Daten, die für eine Wiederholung nötig sind.
class VorgangPersistenzFehler extends Equatable {
  final VorgangPersistenzAktion aktion;
  final String meldung;

  /// Der nicht gespeicherte Vorgang (nur bei [VorgangPersistenzAktion.speichern]).
  final Vorgang? vorgang;

  /// Die nicht gelöschte Referenz (nur bei [VorgangPersistenzAktion.loeschen]).
  final String? referenz;

  /// Zeitpunkt des Fehlers — unterscheidet zwei gleiche Fehler nacheinander,
  /// damit der Cubit beide emittiert und die Snackbar erneut erscheint.
  final DateTime zeitpunkt;

  VorgangPersistenzFehler({
    required this.aktion,
    required this.meldung,
    this.vorgang,
    this.referenz,
    DateTime? zeitpunkt,
  }) : zeitpunkt = zeitpunkt ?? DateTime.now();

  @override
  List<Object?> get props => [aktion, meldung, vorgang, referenz, zeitpunkt];
}
