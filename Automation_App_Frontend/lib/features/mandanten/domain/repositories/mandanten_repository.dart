import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';

/// Schnittstelle des Kundensystems: das lokale Mandantenregister (strukturierte
/// Daten) plus das dateibasierte Aktensystem (§6.1). Implementierung verknüpft
/// beide über den Akten-Ordnernamen.
abstract class MandantenRepository {
  /// Alle Mandanten aus dem Register.
  Future<Either<Failure, List<Mandant>>> getMandanten();

  Future<Either<Failure, Mandant>> createMandant(CreateMandantRequest request);

  Future<Either<Failure, Mandant>> updateMandant(Mandant mandant);

  Future<Either<Failure, void>> deleteMandant(int id);

  /// Scannt den in den Einstellungen hinterlegten Stammordner **flach** und
  /// liefert die gefundenen Akten (Ordner) ohne ihre Fälle — die kommen bei
  /// Bedarf über [getFaelle] nach. Leere Liste, wenn kein Stammordner gesetzt
  /// ist oder er nicht existiert.
  Future<Either<Failure, List<Akte>>> getAkten();

  /// Die Fälle einer einzelnen Akte. [aktenPfad] ist der `pfad` der Akte aus
  /// [getAkten].
  Future<Either<Failure, List<Fall>>> getFaelle(String aktenPfad);

  /// Die Ordner, für die entschieden ist, dass sie keinem Mandanten gehören.
  Future<Either<Failure, List<OrdnerStatus>>> getOrdnerStatus();

  /// Setzt [art] für alle [ordnernamen]; `null` nimmt den Vermerk zurück.
  /// Liefert den vollständigen Stand danach.
  Future<Either<Failure, List<OrdnerStatus>>> setzeOrdnerStatus({
    required List<String> ordnernamen,
    required OrdnerStatusArt? art,
  });

  /// Liest eine Importdatei von der Platte (§5.1/§6.1). Deutet sie nicht —
  /// was sie bewirkt, sagt erst [importiereMandanten].
  Future<Either<Failure, MandantenImportDatei>> liesImportDatei(String pfad);

  /// Prüft die Datei gegen das Register oder übernimmt sie. Ohne [uebernehmen]
  /// wird nichts geschrieben; der Bericht ist in beiden Fällen derselbe.
  Future<Either<Failure, ImportBericht>> importiereMandanten({
    required MandantenImportDatei datei,
    required bool uebernehmen,
  });

  /// Ordnet einem Mandanten einen vorhandenen Akten-Ordner zu (manuelle
  /// Zuordnung). Gibt den aktualisierten Mandanten zurück.
  Future<Either<Failure, Mandant>> verknuepfeOrdner({
    required int mandantId,
    required String ordnername,
  });

  /// Legt ein fertiges Dokument in der Akte ab (§6.1): Akten-Ordner bei Bedarf
  /// anlegen, Unterordner anlegen, Dateien hineinkopieren. Verknüpft den
  /// Ordner mit dem Mandanten und gibt die Zielpfade der Kopien zurück.
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

  /// Pfade der Quelldateien: alle Fassungen desselben Schreibens (Word, PDF
  /// oder beide), üblicherweise die Arbeitskopien im Arbeitsordner des
  /// Vorgangs. Sie werden als ein Vorgang abgelegt — siehe [AblageErgebnis].
  final List<String> quelldateiPfade;

  /// Was geschehen soll, wenn im Fall-Ordner bereits eine gleichnamige Datei
  /// liegt. Standard: nicht überschreiben, sondern zurückfragen.
  final AblageStrategie strategie;

  const LegeDokumentAbParams({
    required this.mandantId,
    required this.aktenOrdnername,
    required this.unterordnerName,
    required this.quelldateiPfade,
    this.strategie = AblageStrategie.fragen,
  });

  /// Dieselbe Anfrage mit der Entscheidung des Anwalts — für den zweiten
  /// Anlauf nach einer Rückfrage.
  LegeDokumentAbParams mitStrategie(AblageStrategie strategie) =>
      LegeDokumentAbParams(
        mandantId: mandantId,
        aktenOrdnername: aktenOrdnername,
        unterordnerName: unterordnerName,
        quelldateiPfade: quelldateiPfade,
        strategie: strategie,
      );
}
