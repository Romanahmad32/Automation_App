import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/usecases/importiere_mandanten.dart';
import 'package:automation_app/features/mandanten/domain/usecases/lies_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mandanten_testaufbau.dart';

/// Attrappen und Bausteine für die Tests rund um den [MandantenImportCubit].
///
/// Akten-Scan und Registereinträge kommen aus `mandanten_testaufbau.dart` —
/// dieselben Attrappen wie im Zuordnungsstapel, damit nicht zwei Fassungen
/// desselben Dateisystems nebeneinander altern.

/// Die Importansicht unter ihrem Cubit — so, wie die Seite sie aufhängt.
Widget importSeite(MandantenImportCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider.value(
      value: cubit,
      child: BlocBuilder<MandantenImportCubit, MandantenImportState>(
        builder: (context, state) => MandantenImportView(state: state),
      ),
    ),
  ),
);

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

/// Das Register als Ganzes (`GET /api/Mandanten`) — Grundlage des
/// Ähnlichkeitshinweises.
class FestesRegister implements UseCase<List<Mandant>, NoParams> {
  final List<Mandant> mandanten;
  int aufrufe = 0;

  FestesRegister(this.mandanten);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return Right(mandanten);
  }
}

/// Merkt sich, ob geprüft oder geschrieben wurde — der Kern der Sache: vor der
/// ersten Vorschau darf nichts geschrieben werden.
class AufzeichnenderImport
    implements UseCase<ImportBericht, ImportiereMandantenParams> {
  final ImportBericht antwort;

  /// Antwortet abhängig von der geschickten Datei, statt immer [antwort] zu
  /// liefern. Gebraucht dort, wo eine berichtigte Zeile ihr Urteil ändern soll
  /// — „aus neu wird ergänzt" ist sonst nicht prüfbar, weil eine feste Antwort
  /// die Berichtigung gar nicht bemerkt.
  final ImportBericht Function(MandantenImportDatei datei)? berichtVon;

  /// Ob der jeweilige Aufruf schreiben sollte — in der Reihenfolge.
  final List<bool> aufrufe = [];

  /// Die Datei, wie sie beim jeweiligen Aufruf über die Leitung ging. Nach dem
  /// Bearbeiten einer Zeile muss dort die berichtigte Fassung stehen.
  final List<MandantenImportDatei> gesendet = [];

  String? fehler;

  AufzeichnenderImport(this.antwort, {this.fehler, this.berichtVon});

  int get schreibendeAufrufe => aufrufe.where((u) => u).length;

  @override
  Future<Either<Failure, ImportBericht>> call(
    ImportiereMandantenParams params,
  ) async {
    aufrufe.add(params.uebernehmen);
    gesendet.add(params.datei);
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));
    final basis = berichtVon?.call(params.datei) ?? antwort;
    return Right(
      params.uebernehmen
          ? ImportBericht(
              eintraege: basis.eintraege,
              neu: basis.neu,
              ergaenzt: basis.ergaenzt,
              unveraendert: basis.unveraendert,
              abgelehnt: basis.abgelehnt,
              ordnerZugeordnet: basis.ordnerZugeordnet,
              ohneMandantenbezug: basis.ohneMandantenbezug,
              angewendet: true,
            )
          : basis,
    );
  }
}

/// Cubit samt seinen Attrappen.
class ImportTestaufbau {
  final FesteImportDatei lesen;
  final AufzeichnenderImport importieren;

  /// Der Akten-Scan. `aufrufe` zeigt, dass er genau einmal läuft — nicht je
  /// geprüfter Datei und schon gar nicht je geöffnetem Dialog.
  final ZaehlenderAktenScan scan;

  final FestesRegister register;
  final MandantenImportCubit cubit;

  ImportTestaufbau._(
    this.lesen,
    this.importieren,
    this.scan,
    this.register,
    this.cubit,
  );

  /// [ordner] sind die Ordnernamen unter dem Stammordner; **leer heißt: kein
  /// Scan**, und dann sperrt keine Ordnerangabe die Übernahme.
  factory ImportTestaufbau({
    MandantenImportDatei? inhalt,
    ImportBericht? antwort,
    ImportBericht Function(MandantenImportDatei datei)? berichtVon,
    List<String> ordner = const [],
    List<Mandant> register = const [],
  }) {
    final lesen = FesteImportDatei(inhalt ?? datei());
    final importieren = AufzeichnenderImport(
      antwort ?? bericht(eintraege: [eintrag(0)], neu: 1, ordnerZugeordnet: 1),
      berichtVon: berichtVon,
    );
    final scan = ZaehlenderAktenScan([for (final name in ordner) akte(name)]);
    final registerQuelle = FestesRegister([...register]);
    return ImportTestaufbau._(
      lesen,
      importieren,
      scan,
      registerQuelle,
      MandantenImportCubit(lesen, importieren, scan, registerQuelle),
    );
  }

  /// Lädt Scan und Register — das, was die Seite beim Öffnen anstößt.
  Future<void> umfeld() => cubit.umfeldLaden();

  /// Der übliche Einstieg: Umfeld laden, Datei wählen, Vorschau steht.
  Future<void> geoeffnet([String pfad = 'C:/tmp/import.json']) async {
    await umfeld();
    await cubit.dateiWaehlen(pfad);
  }

  Future<void> close() => cubit.close();
}
