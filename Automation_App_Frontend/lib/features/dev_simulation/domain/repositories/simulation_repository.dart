import 'package:automation_app/features/dev_simulation/domain/entities/zentralruf_antwort_typ.dart';

/// Port der Entwickler-Simulation: speist eine synthetische Zentralruf-Antwort
/// in die echte Postfach-Pipeline des Backends ein (Parser → Inbox-Store →
/// SignalR-Push). Funktioniert nur, wenn das Backend im Development-Profil
/// läuft (`Simulation:Enabled`); sonst antwortet es mit 404.
abstract class SimulationRepository {
  Future<void> simuliereZentralrufAntwort({
    required String referenz,
    String? kennzeichen,
    String? unfallDatum,
    String? versichererName,
    ZentralrufAntwortTyp antwortTyp = ZentralrufAntwortTyp.versicherer,
  });
}
