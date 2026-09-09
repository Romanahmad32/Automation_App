import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_nummern_stand.dart';

/// Port für den Nummernstand eines Jahrgangs (§6.3): der Vorschlag für die
/// nächste laufende Nummer und die im Jahrgang schon belegten.
///
/// Gelesen wird das u. a. von `vorgang_starten`, für den Vorschlag der
/// Auftragsnummer beim Anlegen eines Vorgangs — wie es dort schon die
/// Einstellungen eines anderen Features liest.
abstract class RegisterNummernRepository {
  /// Ohne [jahrgang] gilt das laufende Kalenderjahr (Vorgabe des Dienstes).
  Future<Either<Failure, RegisterNummernStand>> ladeNummernstand({
    int? jahrgang,
  });
}
