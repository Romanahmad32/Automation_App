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
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
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

  @override
  Future<Either<Failure, Mandant>> verknuepfeOrdner({
    required int mandantId,
    required String ordnername,
  }) => alsEither(
    () async =>
        _verknuepfe(await _datasource.loadMandanten(), mandantId, ordnername),
    uebersetzen: _localFailure,
  );

  @override
  Future<Either<Failure, Mandant>> loeseOrdner({
    required int mandantId,
    required String ordnername,
  }) => alsEither(() async {
    final mandant = _finde(await _datasource.loadMandanten(), mandantId);
    final geloest = OrdnernamenMenge([ordnername]);
    return _datasource.updateMandant(
      mandant.copyWith(
        aktenOrdnernamen: [
          for (final name in mandant.aktenOrdnernamen)
            if (!geloest.enthaelt(name)) name,
        ],
      ),
    );
  }, uebersetzen: _localFailure);

  @override
  Future<Either<Failure, AblageErgebnis>> legeDokumentAb(
    LegeDokumentAbParams params,
  ) => alsEither(() async {
    // Vor dem Kopieren: Das Backend lehnte die Zuordnung sonst erst ab, wenn
    // die Datei schon in der fremden Akte liegt.
    _pruefeOrdnerFrei(
      await _datasource.loadMandanten(),
      params.mandantId,
      params.aktenOrdnername,
    );
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
    //
    // Das Register **neu** laden statt die Liste von vor dem Kopieren zu
    // nehmen: Gespeichert wird der ganze Mandant, und eine Änderung an ihm
    // während des Kopierens ginge sonst verloren. Ein zweiter Abruf bei der
    // seltenen Ablage ist billiger als ein stilles Überschreiben.
    if (!ergebnis.konflikt) {
      await _verknuepfe(
        await _datasource.loadMandanten(),
        params.mandantId,
        params.aktenOrdnername,
      );
    }
    return ergebnis;
  }, uebersetzen: _localFailure);

  /// Fügt [ordnername] zu den Akten des Mandanten hinzu (idempotent) und
  /// speichert. Gibt den aktualisierten Mandanten zurück. [mandanten] ist das
  /// frisch geladene Register.
  Future<Mandant> _verknuepfe(
    List<Mandant> mandanten,
    int mandantId,
    String ordnername,
  ) async {
    final mandant = _finde(mandanten, mandantId);
    // Ohne Rücksicht auf die Schreibweise: der Ordnername kommt aus dem
    // Dateisystem, und „VUnfallursache Mark" zweimal verschieden geschrieben
    // stünde sonst zweimal am Mandanten.
    if (OrdnernamenMenge(mandant.aktenOrdnernamen).enthaelt(ordnername)) {
      return mandant;
    }
    final aktualisiert = mandant.copyWith(
      aktenOrdnernamen: [...mandant.aktenOrdnernamen, ordnername],
    );
    return _datasource.updateMandant(aktualisiert);
  }

  Mandant _finde(List<Mandant> mandanten, int mandantId) =>
      mandanten.firstWhere(
        (m) => m.id == mandantId,
        orElse: () =>
            throw StateError('Mandant mit ID $mandantId nicht gefunden'),
      );

  /// Wirft, wenn [ordnername] einem anderen als [mandantId] gehört — mit
  /// derselben Aussage wie das 409 des Backends, das die Regel ebenso
  /// durchsetzt. Hier nur, damit die Ablage vor dem Kopieren abbricht.
  void _pruefeOrdnerFrei(
    List<Mandant> mandanten,
    int mandantId,
    String ordnername,
  ) {
    for (final m in mandanten) {
      if (m.id == mandantId) continue;
      if (!OrdnernamenMenge(m.aktenOrdnernamen).enthaelt(ordnername)) continue;
      final besitzer = m.anzeigename.isEmpty
          ? 'einem anderen Mandanten'
          : m.anzeigename;
      throw MandantException(
        'Der Ordner „$ordnername" gehört bereits $besitzer — ein Ordner kann '
        'nur einem Mandanten zugeordnet sein. Es wurde nichts abgelegt.',
      );
    }
  }

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
