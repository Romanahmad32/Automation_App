import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/delete_mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_faelle.dart';
import 'package:automation_app/features/mandanten/domain/usecases/setze_ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';

/// Attrappen und Bausteine für die Tests rund um den [MandantenOverviewBloc] —
/// von Bloc-Test und Widget-Test gemeinsam genutzt.
final DateTime angelegt = DateTime(2026, 1, 1);

Mandant mandant(int id, String nachname, {List<String> ordner = const []}) =>
    Mandant(
      id: id,
      nachname: nachname,
      aktenOrdnernamen: ordner,
      erstelltAm: angelegt,
    );

Akte akte(String ordnername) =>
    Akte(ordnername: ordnername, pfad: 'C:/Akten/$ordnername');

/// Zählt die Aufrufe mit — der Kern der Sache: nach einer Zuordnung darf der
/// Stammordner **nicht** erneut gescannt werden.
class ZaehlenderAktenScan implements UseCase<List<Akte>, NoParams> {
  final List<Akte> akten;
  int aufrufe = 0;

  ZaehlenderAktenScan(this.akten);

  @override
  Future<Either<Failure, List<Akte>>> call(NoParams params) async {
    aufrufe++;
    return Right(akten);
  }
}

class FesteMandanten implements UseCase<List<Mandant>, NoParams> {
  List<Mandant> mandanten;
  int aufrufe = 0;

  FesteMandanten(this.mandanten);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return Right(mandanten);
  }
}

class FesteFaelle implements UseCase<List<Fall>, GetFaelleParams> {
  final List<Fall> faelle;
  int aufrufe = 0;

  FesteFaelle(this.faelle);

  @override
  Future<Either<Failure, List<Fall>>> call(GetFaelleParams params) async {
    aufrufe++;
    return Right(faelle);
  }
}

/// Verknüpft, indem der Ordner am Mandanten hängend zurückkommt — genau das,
/// was der Bloc in den Zustand fortschreiben soll.
class FakeVerknuepfen implements UseCase<Mandant, VerknuepfeOrdnerParams> {
  final List<Mandant> register;

  FakeVerknuepfen(this.register);

  @override
  Future<Either<Failure, Mandant>> call(VerknuepfeOrdnerParams params) async {
    final alt = register.firstWhere((m) => m.id == params.mandantId);
    return Right(
      mandant(
        alt.id,
        alt.nachname,
        ordner: [...alt.aktenOrdnernamen, params.ordnername],
      ),
    );
  }
}

/// Haelt die Vermerke im Speicher — geteilt von Lesen und Schreiben, wie die
/// eine Tabelle im Backend.
class OrdnerStatusSpeicher {
  final Map<String, OrdnerStatus> eintraege = {};
  int setzAufrufe = 0;

  List<OrdnerStatus> get stand =>
      eintraege.values.toList()
        ..sort((a, b) => a.ordnername.compareTo(b.ordnername));
}

class FesteOrdnerStatus implements UseCase<List<OrdnerStatus>, NoParams> {
  final OrdnerStatusSpeicher speicher;

  FesteOrdnerStatus(this.speicher);

  @override
  Future<Either<Failure, List<OrdnerStatus>>> call(NoParams params) async =>
      Right(speicher.stand);
}

/// Antwortet wie der Dienst mit dem vollstaendigen Stand danach — das ist es,
/// was eine Massenaktion zu einem einzigen Zustandswechsel macht.
class FakeSetzeOrdnerStatus
    implements UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams> {
  final OrdnerStatusSpeicher speicher;

  FakeSetzeOrdnerStatus(this.speicher);

  @override
  Future<Either<Failure, List<OrdnerStatus>>> call(
    SetzeOrdnerStatusParams params,
  ) async {
    speicher.setzAufrufe++;
    final art = params.art;
    for (final name in params.ordnernamen) {
      if (art == null) {
        speicher.eintraege.remove(name);
      } else {
        speicher.eintraege[name] = OrdnerStatus(
          ordnername: name,
          art: art,
          gesetztAm: angelegt,
        );
      }
    }
    return Right(speicher.stand);
  }
}

class FakeLoeschen implements UseCase<void, DeleteMandantParams> {
  @override
  Future<Either<Failure, void>> call(DeleteMandantParams params) async =>
      Right(null);
}

/// Bloc samt seinen Attrappen — die Tests prüfen an ihnen die Aufrufzahlen.
class MandantenTestaufbau {
  final FesteMandanten getMandanten;
  final ZaehlenderAktenScan getAkten;
  final FesteFaelle getFaelle;
  final OrdnerStatusSpeicher ordnerStatus;
  final MandantenOverviewBloc bloc;

  MandantenTestaufbau._(
    this.getMandanten,
    this.getAkten,
    this.getFaelle,
    this.ordnerStatus,
    this.bloc,
  );

  factory MandantenTestaufbau({
    List<Mandant> register = const [],
    List<Akte> akten = const [],
    List<Fall> faelle = const [],
  }) {
    final mandanten = FesteMandanten([...register]);
    final scan = ZaehlenderAktenScan(akten);
    final faelleQuelle = FesteFaelle(faelle);
    final speicher = OrdnerStatusSpeicher();
    return MandantenTestaufbau._(
      mandanten,
      scan,
      faelleQuelle,
      speicher,
      MandantenOverviewBloc(
        mandanten,
        scan,
        faelleQuelle,
        FesteOrdnerStatus(speicher),
        FakeSetzeOrdnerStatus(speicher),
        FakeLoeschen(),
        FakeVerknuepfen(mandanten.mandanten),
      ),
    );
  }

  /// Lädt und wartet, bis der geladene Zustand steht.
  Future<MandantenOverviewLoaded> laden() async {
    bloc.add(const LoadMandantenUebersichtEvent());
    return await bloc.stream.firstWhere((s) => s is MandantenOverviewLoaded)
        as MandantenOverviewLoaded;
  }

  /// Der nächste Zustand nach einem Ereignis.
  Future<MandantenOverviewLoaded> naechster() async =>
      await bloc.stream.first as MandantenOverviewLoaded;

  Future<void> close() => bloc.close();
}
