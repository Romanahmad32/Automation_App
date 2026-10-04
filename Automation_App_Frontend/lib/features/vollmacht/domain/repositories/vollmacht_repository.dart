import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';

/// Port der Vollmacht (§4.11). Fehler kommen als [Failure] zurück, damit die
/// Oberfläche sie zeigen **muss** — ein verschluckter Druckfehler hieße, der
/// Mandant geht ohne Vollmacht aus dem Büro.
///
/// Ein gescheiterter Druck ist dagegen **kein** [Failure], sondern ein
/// [VollmachtErgebnis] mit Status: Er hat einen vorgesehenen Ausgang (die
/// Datei in Word öffnen), für den die Oberfläche den Pfad braucht.
abstract class VollmachtRepository {
  /// Der Stand der drei Vorlagen im Unterordner `Vollmacht`.
  Future<Either<Failure, VollmachtVorlagenStand>> ladeVorlagen();

  /// Der Mandant zur [id] — `Right(null)`, wenn es ihn nicht (mehr) gibt.
  Future<Either<Failure, Mandant?>> ladeMandant(int id);

  /// Füllt aus und druckt.
  Future<Either<Failure, VollmachtErgebnis>> drucke(VollmachtAuftrag auftrag);

  /// Füllt nur aus; die Datei bleibt zum Öffnen liegen.
  Future<Either<Failure, VollmachtErgebnis>> fuelleAus(
    VollmachtAuftrag auftrag,
  );

  /// Der Windows-Standarddrucker und was Windows über ihn meldet.
  Future<Either<Failure, VollmachtDrucker>> ladeDrucker();

  /// Die ausgefüllte Seite als PDF; der Dienst behält nichts davon.
  Future<Either<Failure, VollmachtVorschau>> erstelleVorschau(
    VollmachtAuftrag auftrag,
  );
}
