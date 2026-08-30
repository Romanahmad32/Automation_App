import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';

/// Liest und speichert die konfigurierten Standardpositionen der
/// Schadensaufstellung (§4.4). Gespeichert wird immer die komplette Liste;
/// eine leere Liste setzt auf die fünf üblichen Positionen zurück.
abstract class StandardSchadenspositionenRepository {
  Future<List<StandardSchadensposition>> lade();

  /// Liefert den gespeicherten Stand zurück, wie das Backend ihn abgelegt hat
  /// (bereinigt um Leerzeilen, bei leerer Liste die Vorgabe).
  Future<List<StandardSchadensposition>> speichere(
    List<StandardSchadensposition> positionen,
  );
}
