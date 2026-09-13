import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/data/datasources/akten_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/arbeitspaket_datei_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_datei_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_paket_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/mandanten_import_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/mandant_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/ordner_status_datasource.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: MandantenRepository)
class MandantenRepositoryImpl implements MandantenRepository {
  final MandantDatasource _datasource;
  final FilesystemAktenDatasource _aktenDatasource;
  final OrdnerStatusDatasource _ordnerStatusDatasource;
  final ImportDateiDatasource _importDateiDatasource;
  final MandantenImportDatasource _importDatasource;
  final ImportPaketDatasource _importPaketDatasource;
  final ArbeitspaketDateiDatasource _arbeitspaketDateiDatasource;
  final KanzleiSettingsRepository _settingsRepository;

  MandantenRepositoryImpl(
    this._datasource,
    this._aktenDatasource,
    this._ordnerStatusDatasource,
    this._importDateiDatasource,
    this._importDatasource,
    this._importPaketDatasource,
    this._arbeitspaketDateiDatasource,
    this._settingsRepository,
  );

  @override
  Future<Either<Failure, List<ImportPaket>>> getImportPakete() => alsEither(
    () => _importPaketDatasource.ladeImportPakete(),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, ImportPaket>> notiereImportPaket(
    List<String> ordnernamen,
  ) => alsEither(
    () => _importPaketDatasource.notiereImportPaket(ordnernamen),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, void>> loescheImportPaket(int nummer) => alsEither(
    () => _importPaketDatasource.loescheImportPaket(nummer),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, void>> schreibeArbeitspaket({
    required Arbeitspaket paket,
    required String pfad,
  }) => alsEither(
    () => _arbeitspaketDateiDatasource.schreibe(paket: paket, pfad: pfad),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, MandantenImportDatei>> liesImportDatei(String pfad) =>
      alsEither(
        () => _importDateiDatasource.lies(pfad),
        uebersetzen: _localFailure,
      );

  @override
  Future<Either<Failure, ImportBericht>> importiereMandanten({
    required MandantenImportDatei datei,
    required bool uebernehmen,
  }) => alsEither(
    () => _importDatasource.importiere(datei: datei, uebernehmen: uebernehmen),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, List<Mandant>>> getMandanten() =>
      alsEither(() => _datasource.loadMandanten(), uebersetzen: _localFailure);

  @override
  Future<Either<Failure, MandantenSeite>> getMandantenSeite({
    String suche = '',
    int ueberspringen = 0,
    int anzahl = 0,
  }) => alsEither(
    () => _datasource.ladeSeite(
      suche: suche,
      ueberspringen: ueberspringen,
      anzahl: anzahl,
    ),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, List<String>>> getAktenOrdnernamen() => alsEither(
    () => _datasource.ladeAktenOrdnernamen(),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, Mandant>> createMandant(
    CreateMandantRequest request,
  ) => alsEither(
    () => _datasource.createMandant(request),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, Mandant>> updateMandant(Mandant mandant) => alsEither(
    () => _datasource.updateMandant(mandant),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, void>> deleteMandant(int id) => alsEither(
    () => _datasource.deleteMandant(id),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, List<Akte>>> getAkten() => alsEither(() async {
    final stammordner = await _ladeStammordner();
    return _aktenDatasource.scanAkten(stammordner);
  }, uebersetzen: _localFailure);

  @override
  Future<Either<Failure, List<Fall>>> getFaelle(String aktenPfad) => alsEither(
    () => _aktenDatasource.scanFaelle(aktenPfad),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, List<OrdnerStatus>>> getOrdnerStatus() => alsEither(
    () => _ordnerStatusDatasource.ladeOrdnerStatus(),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, List<OrdnerStatus>>> setzeOrdnerStatus({
    required List<String> ordnernamen,
    required OrdnerStatusArt? art,
  }) => alsEither(
    () => _ordnerStatusDatasource.setzeOrdnerStatus(
      ordnernamen: ordnernamen,
      art: art,
    ),
    uebersetzen: _localFailure,
  );

  /// Zuordnen und Lösen gehen über je einen eigenen Aufruf, der nur diesen
  /// einen Ordner ändert — nicht über „Mandant laden, Liste ändern, ganzen
  /// Mandanten speichern". Das überschrieb eine zweite Änderung, die sich
  /// damit überschnitt, und holte dafür jedes Mal das ganze Register.
  @override
  Future<Either<Failure, Mandant>> verknuepfeOrdner({
    required int mandantId,
    required String ordnername,
  }) => alsEither(
    () =>
        _datasource.ordneOrdnerZu(mandantId: mandantId, ordnername: ordnername),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, Mandant>> loeseOrdner({
    required int mandantId,
    required String ordnername,
  }) => alsEither(
    () => _datasource.loeseOrdner(mandantId: mandantId, ordnername: ordnername),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, AblageErgebnis>> legeDokumentAb(
    LegeDokumentAbParams params,
  ) => alsEither(() async {
    // Vor dem Kopieren fragen, ob die Zuordnung danach geht — sonst lehnte
    // der Dienst sie erst ab, wenn die Datei schon in der fremden Akte liegt.
    // Dieselbe Prüfung wie beim Zuordnen, nur ohne zu schreiben: Ob der
    // Ordner diesem Mandanten schon gehört, zählt dabei mit.
    try {
      await _datasource.ordneOrdnerZu(
        mandantId: params.mandantId,
        ordnername: params.aktenOrdnername,
        nurPruefen: true,
      );
    } on MandantException catch (e) {
      throw MandantException('${e.message} Es wurde nichts abgelegt.');
    }
    final stammordner = await _ladeStammordner();
    final ergebnis = await _aktenDatasource.legeDokumentAb(
      stammordner: stammordner,
      ordnername: params.aktenOrdnername,
      unterordnerName: params.unterordnerName,
      quelldateiPfade: params.quelldateiPfade,
      strategie: params.strategie,
    );
    // Register und Dateisystem in Einklang halten: den (ggf. neu angelegten)
    // Akten-Ordner dem Mandanten zuordnen. Bei einer offenen Rückfrage liegt
    // noch nichts in der Akte — dann auch nichts zu verknüpfen.
    if (!ergebnis.konflikt) {
      await _datasource.ordneOrdnerZu(
        mandantId: params.mandantId,
        ordnername: params.aktenOrdnername,
      );
    }
    return ergebnis;
  }, uebersetzen: _localFailure);

  Future<String> _ladeStammordner() async {
    final result = await _settingsRepository.getSettings();
    return switch (result) {
      Right(value: final settings) => settings.aktenStammordner,
      Left() => '',
    };
  }

  /// Alle Ausnahmen dieses Repositories landen als [LocalFailure] — die
  /// Datasources sprechen kein HTTP, sondern Dateisystem und lokale
  /// Datenbank. `ausnahmeText` liefert für `MandantException` denselben
  /// Klartext wie ihr `message`-Feld (siehe deren `toString()`).
  Failure _localFailure(Object fehler) =>
      LocalFailure(message: ausnahmeText(fehler));
}
