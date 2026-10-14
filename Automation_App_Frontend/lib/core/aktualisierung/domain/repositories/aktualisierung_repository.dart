import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';

/// Port der Aktualisierung aus der App heraus (#196). Jeder Schritt liefert
/// den ganzen Stand danach; eine Ablehnung des Dienstes (409) oder ein Dienst
/// ohne Antwort kommt als [Failure] mit einem Satz für den Anwender zurück.
abstract class AktualisierungRepository {
  /// Der zwischengespeicherte Stand — billig, wird während des Downloads
  /// abgefragt.
  Future<Either<Failure, AktualisierungsStand>> stand();

  /// Fragt die Update-Quelle. Kein Netz ist kein [Failure], sondern der
  /// Zustand `unbekannt` mit Meldung.
  Future<Either<Failure, AktualisierungsStand>> pruefen();

  /// Startet den Download im Dienst; er läuft dort im Hintergrund weiter.
  Future<Either<Failure, AktualisierungsStand>> herunterladen();

  /// Bricht den Download ab; die Teildatei ist danach gelöscht.
  Future<Either<Failure, AktualisierungsStand>> abbrechen();

  /// Prüft die Setup-Datei noch einmal und startet den Installer. Danach muss
  /// die App sich beenden — das Setup wartet, bis der Dienst fort ist.
  Future<Either<Failure, AktualisierungsStand>> installieren();

  /// Das Ergebnis der letzten Aktualisierung ist gezeigt worden.
  Future<Either<Failure, void>> ergebnisQuittieren();
}
