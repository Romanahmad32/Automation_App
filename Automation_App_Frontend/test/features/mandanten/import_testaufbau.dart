import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/usecases/importiere_mandanten.dart';
import 'package:automation_app/features/mandanten/domain/usecases/lies_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';

/// Attrappen und Bausteine für die Tests rund um den [MandantenImportCubit].

ImportEintrag eintrag(
  int zeile, {
  String name = 'Mark Schmidt',
  List<String> ordner = const ['VUnfallursache Schmidt'],
  ImportArt art = ImportArt.neu,
  List<String> hinweise = const [],
  ImportSicherheit sicherheit = ImportSicherheit.hoch,
}) => ImportEintrag(
  zeile: zeile,
  anzeigename: name,
  aktenOrdnernamen: ordner,
  art: art,
  hinweise: hinweise,
  sicherheit: sicherheit,
);

ImportBericht bericht({
  List<ImportEintrag> eintraege = const [],
  int neu = 0,
  int ergaenzt = 0,
  int unveraendert = 0,
  int abgelehnt = 0,
  int ordnerZugeordnet = 0,
  int ohneMandantenbezug = 0,
  bool angewendet = false,
}) => ImportBericht(
  eintraege: eintraege,
  neu: neu,
  ergaenzt: ergaenzt,
  unveraendert: unveraendert,
  abgelehnt: abgelehnt,
  ordnerZugeordnet: ordnerZugeordnet,
  ohneMandantenbezug: ohneMandantenbezug,
  angewendet: angewendet,
);

MandantenImportDatei datei({int mandanten = 1}) => MandantenImportDatei(
  mandanten: [
    for (var i = 0; i < mandanten; i++)
      ImportMandantEintrag(
        vorname: 'Mark',
        nachname: 'Schmidt $i',
        ort: 'Bad Homburg',
        aktenOrdnernamen: ['VUnfallursache Schmidt $i'],
        quelle: 'Schmidt $i/Schreiben.docx',
        sicherheit: 'mittel',
      ),
  ],
);

/// Liefert eine Datei — oder scheitert, wenn [fehler] gesetzt ist.
class FesteImportDatei
    implements UseCase<MandantenImportDatei, LiesImportDateiParams> {
  final MandantenImportDatei inhalt;
  String? fehler;
  int aufrufe = 0;

  FesteImportDatei(this.inhalt, {this.fehler});

  @override
  Future<Either<Failure, MandantenImportDatei>> call(
    LiesImportDateiParams params,
  ) async {
    aufrufe++;
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));
    return Right(inhalt);
  }
}

/// Merkt sich, ob geprüft oder geschrieben wurde — der Kern der Sache: vor der
/// ersten Vorschau darf nichts geschrieben werden.
class AufzeichnenderImport
    implements UseCase<ImportBericht, ImportiereMandantenParams> {
  final ImportBericht antwort;

  /// Ob der jeweilige Aufruf schreiben sollte — in der Reihenfolge.
  final List<bool> aufrufe = [];

  /// Die Datei, wie sie beim jeweiligen Aufruf über die Leitung ging. Nach dem
  /// Bearbeiten einer Zeile muss dort die berichtigte Fassung stehen.
  final List<MandantenImportDatei> gesendet = [];

  String? fehler;

  AufzeichnenderImport(this.antwort, {this.fehler});

  int get schreibendeAufrufe => aufrufe.where((u) => u).length;

  @override
  Future<Either<Failure, ImportBericht>> call(
    ImportiereMandantenParams params,
  ) async {
    aufrufe.add(params.uebernehmen);
    gesendet.add(params.datei);
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));
    return Right(
      params.uebernehmen
          ? ImportBericht(
              eintraege: antwort.eintraege,
              neu: antwort.neu,
              ergaenzt: antwort.ergaenzt,
              unveraendert: antwort.unveraendert,
              abgelehnt: antwort.abgelehnt,
              ordnerZugeordnet: antwort.ordnerZugeordnet,
              ohneMandantenbezug: antwort.ohneMandantenbezug,
              angewendet: true,
            )
          : antwort,
    );
  }
}

/// Cubit samt seinen Attrappen.
class ImportTestaufbau {
  final FesteImportDatei lesen;
  final AufzeichnenderImport importieren;
  final MandantenImportCubit cubit;

  ImportTestaufbau._(this.lesen, this.importieren, this.cubit);

  factory ImportTestaufbau({
    MandantenImportDatei? inhalt,
    ImportBericht? antwort,
  }) {
    final lesen = FesteImportDatei(inhalt ?? datei());
    final importieren = AufzeichnenderImport(
      antwort ?? bericht(eintraege: [eintrag(0)], neu: 1, ordnerZugeordnet: 1),
    );
    return ImportTestaufbau._(
      lesen,
      importieren,
      MandantenImportCubit(lesen, importieren),
    );
  }

  Future<void> close() => cubit.close();
}
