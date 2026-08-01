import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';

/// Schnittstelle des Kundensystems: das lokale Mandantenregister (strukturierte
/// Daten) plus das dateibasierte Aktensystem (§3.6). Implementierung verknüpft
/// beide über den Akten-Ordnernamen.
abstract class MandantenRepository {
  /// Alle Mandanten aus dem Register.
  Future<Either<Failure, List<Mandant>>> getMandanten();

  Future<Either<Failure, Mandant>> createMandant(CreateMandantRequest request);

  Future<Either<Failure, Mandant>> updateMandant(Mandant mandant);

  Future<Either<Failure, void>> deleteMandant(int id);

  /// Scannt den in den Einstellungen hinterlegten Stammordner und liefert die
  /// gefundenen Akten (Ordner) samt Fällen. Leere Liste, wenn kein Stammordner
  /// gesetzt ist oder er nicht existiert.
  Future<Either<Failure, List<Akte>>> getAkten();

  /// Ordnet einem Mandanten einen vorhandenen Akten-Ordner zu (manuelle
  /// Zuordnung). Gibt den aktualisierten Mandanten zurück.
  Future<Either<Failure, Mandant>> verknuepfeOrdner({
    required int mandantId,
    required String ordnername,
  });

  /// Legt ein fertiges Dokument in der Akte ab (§3.6): Akten-Ordner bei Bedarf
  /// anlegen, Unterordner anlegen, Datei hineinkopieren. Verknüpft den
  /// Ordner mit dem Mandanten und gibt den Zielpfad der Kopie zurück.
  Future<Either<Failure, String>> legeDokumentAb(LegeDokumentAbParams params);
}

/// Parameter für [MandantenRepository.legeDokumentAb].
class LegeDokumentAbParams {
  /// Mandant, dem die Akte gehört (für die Verknüpfung im Register).
  final int mandantId;

  /// Ordnername der Ziel-Akte unter dem Stammordner. Existiert er noch nicht,
  /// wird er angelegt (Neumandant bzw. neue Akte).
  final String aktenOrdnername;

  /// Name des Unterordners (Fall), z. B. „Unfall v. 12.05.2019".
  final String unterordnerName;

  /// Pfad der Quelldatei (das generierte Dokument im Backend-Generated-Ordner).
  final String quelldateiPfad;

  const LegeDokumentAbParams({
    required this.mandantId,
    required this.aktenOrdnername,
    required this.unterordnerName,
    required this.quelldateiPfad,
  });
}
