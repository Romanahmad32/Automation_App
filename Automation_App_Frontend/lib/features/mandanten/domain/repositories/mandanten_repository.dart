import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';

/// Schnittstelle des Kundensystems: das lokale Mandantenregister (strukturierte
/// Daten) plus das dateibasierte Aktensystem (§6.1). Implementierung verknüpft
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

  /// Legt ein fertiges Dokument in der Akte ab (§6.1): Akten-Ordner bei Bedarf
  /// anlegen, Unterordner anlegen, Datei hineinkopieren. Verknüpft den
  /// Ordner mit dem Mandanten und gibt den Zielpfad der Kopie zurück.
  Future<Either<Failure, AblageErgebnis>> legeDokumentAb(
    LegeDokumentAbParams params,
  );
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

  /// Pfad der Quelldatei (die Arbeitskopie im Arbeitsordner des Vorgangs).
  final String quelldateiPfad;

  /// Was geschehen soll, wenn im Fall-Ordner bereits eine gleichnamige Datei
  /// liegt. Standard: nicht überschreiben, sondern zurückfragen.
  final AblageStrategie strategie;

  const LegeDokumentAbParams({
    required this.mandantId,
    required this.aktenOrdnername,
    required this.unterordnerName,
    required this.quelldateiPfad,
    this.strategie = AblageStrategie.fragen,
  });

  /// Dieselbe Anfrage mit der Entscheidung des Anwalts — für den zweiten
  /// Anlauf nach einer Rückfrage.
  LegeDokumentAbParams mitStrategie(AblageStrategie strategie) =>
      LegeDokumentAbParams(
        mandantId: mandantId,
        aktenOrdnername: aktenOrdnername,
        unterordnerName: unterordnerName,
        quelldateiPfad: quelldateiPfad,
        strategie: strategie,
      );
}
