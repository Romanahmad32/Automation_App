import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';

/// Port für die übernommene Registerhistorie (§6.2): der Stand je Jahrgang und
/// die Berichtigung einer einzelnen Zeile.
///
/// Die Zeilen selbst laufen **nicht** hierüber, sondern über
/// `RegisterZeilenRepository` — Historie und laufende Vorgänge kommen aus einer
/// Quelle, damit die Ansicht sie in einer Folge zeigen kann.
abstract class RegisterHistorieRepository {
  /// Welche Jahrgänge übernommen sind, welche fehlen, welche Lücken offen
  /// blieben.
  Future<RegisterHistorieStand> ladeStand();

  /// Den Rohstand **einer** Zeile in Einzelfeldern — für den
  /// Bearbeiten-Dialog. Die Tabelle bekommt die Anzeigeform über
  /// `RegisterZeilenRepository`; erst beim Öffnen des Dialogs zählt, was in
  /// welchem Feld steht.
  Future<RegisterHistorieZeile> lade(int id);

  /// Berichtigt eine historische Zeile. Die Rückfrage davor holt die
  /// Oberfläche ein — was hier ankommt, ist bereits die Entscheidung des
  /// Anwalts.
  Future<void> aendere(int id, RegisterHistorieAenderung aenderung);
}
