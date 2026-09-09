import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/delete_mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_faelle.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/usecases/loesche_import_paket.dart';
import 'package:automation_app/features/mandanten/domain/usecases/notiere_import_paket.dart';
import 'package:automation_app/features/mandanten/domain/usecases/schreibe_arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/usecases/setze_ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';

/// Attrappen und Bausteine für die Tests rund um den [MandantenOverviewBloc] —
/// von Bloc-Test und Widget-Test gemeinsam genutzt.
final DateTime angelegt = DateTime(2026, 1, 1);

Mandant mandant(
  int id,
  String nachname, {
  String vorname = '',
  List<String> ordner = const [],
  List<String> kennzeichen = const [],
}) => Mandant(
  id: id,
  vorname: vorname,
  nachname: nachname,
  aktenOrdnernamen: ordner,
  kennzeichen: kennzeichen,
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

/// Das Register im Speicher — geteilt von Seitenabruf, Ordnernamen und
/// Verknüpfen, wie die eine Tabelle im Backend. Die Suche arbeitet über
/// denselben Bestand wie der Dienst und nicht über den geholten Ausschnitt.
class MandantenSpeicher {
  final List<Mandant> mandanten;
  int seitenAufrufe = 0;

  MandantenSpeicher(this.mandanten);

  List<Mandant> treffer(String suche) {
    final q = suche.trim().toLowerCase();
    if (q.isEmpty) return mandanten;
    return [
      for (final m in mandanten)
        if (m.anzeigename.toLowerCase().contains(q) ||
            m.ort.toLowerCase().contains(q) ||
            m.aktenOrdnernamen.any((o) => o.toLowerCase().contains(q)))
          m,
    ];
  }

  void ersetze(Mandant neu) {
    final i = mandanten.indexWhere((m) => m.id == neu.id);
    if (i >= 0) mandanten[i] = neu;
  }
}

/// Antwortet wie `GET /api/Mandanten/seite`: ein Ausschnitt plus die beiden
/// Zahlen, die ihn einordnen.
class FesteMandantenSeite
    implements UseCase<MandantenSeite, MandantenSeiteParams> {
  final MandantenSpeicher speicher;

  FesteMandantenSeite(this.speicher);

  @override
  Future<Either<Failure, MandantenSeite>> call(
    MandantenSeiteParams params,
  ) async {
    speicher.seitenAufrufe++;
    final treffer = speicher.treffer(params.suche);
    final anzahl = params.anzahl > 0
        ? params.anzahl
        : MandantenOverviewBloc.seitenGroesse;
    return Right(
      MandantenSeite(
        mandanten: treffer.skip(params.ueberspringen).take(anzahl).toList(),
        gesamt: speicher.mandanten.length,
        gefiltert: treffer.length,
      ),
    );
  }
}

/// Die zugeordneten Ordner des **ganzen** Registers — unabhängig davon, welche
/// Seite gerade geladen ist.
class FesteAktenOrdnernamen implements UseCase<List<String>, NoParams> {
  final MandantenSpeicher speicher;

  FesteAktenOrdnernamen(this.speicher);

  @override
  Future<Either<Failure, List<String>>> call(NoParams params) async =>
      Right([for (final m in speicher.mandanten) ...m.aktenOrdnernamen]);
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
  final MandantenSpeicher speicher;

  FakeVerknuepfen(this.speicher);

  @override
  Future<Either<Failure, Mandant>> call(VerknuepfeOrdnerParams params) async {
    final alt = speicher.mandanten.firstWhere((m) => m.id == params.mandantId);
    final neu = mandant(
      alt.id,
      alt.nachname,
      ordner: [...alt.aktenOrdnernamen, params.ordnername],
    );
    speicher.ersetze(neu);
    return Right(neu);
  }
}

/// Haelt die Vermerke im Speicher — geteilt von Lesen und Schreiben, wie die
/// eine Tabelle im Backend.
class OrdnerStatusSpeicher {
  final Map<String, OrdnerStatus> eintraege = {};
  int setzAufrufe = 0;

  /// Scheitert der nächste Schreibversuch? Für den Fall, in dem eine
  /// Massenaktion nicht durchgeht.
  String? fehlerBeimSetzen;

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
    final fehler = speicher.fehlerBeimSetzen;
    if (fehler != null) return Left(LocalFailure(message: fehler));
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

/// Das komplette Register für „Arbeitspaket holen" und „Sichere Treffer" —
/// dieselbe [MandantenSpeicher], damit ein im Test angelegter Mandant beiden
/// Wegen bekannt ist.
class FesteMandanten implements UseCase<List<Mandant>, NoParams> {
  final MandantenSpeicher speicher;
  int aufrufe = 0;

  FesteMandanten(this.speicher);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return Right(speicher.mandanten);
  }
}

/// Liefert einen festen Stammordner, wie ihn `KanzleiSettings` sonst aus den
/// Einstellungen holt.
class FesteKanzleiSettings implements UseCase<KanzleiSettings, NoParams> {
  final String stammordner;

  FesteKanzleiSettings(this.stammordner);

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(KanzleiSettings(aktenStammordner: stammordner));
}

/// Die Paket-Historie im Speicher — geteilt vom Lesen (`GetImportPakete`) und
/// vom Verbuchen (`NotiereImportPaket`), wie die eine Tabelle im Backend.
class ImportPaketeSpeicher {
  List<ImportPaket> pakete;
  int leseAufrufe = 0;
  int notiereAufrufe = 0;
  int loeschAufrufe = 0;
  String? fehlerBeimNotieren;
  String? fehlerBeimLoeschen;

  ImportPaketeSpeicher([List<ImportPaket> anfangsbestand = const []])
    : pakete = [...anfangsbestand];
}

class FesteImportPakete implements UseCase<List<ImportPaket>, NoParams> {
  final ImportPaketeSpeicher speicher;

  FesteImportPakete(this.speicher);

  @override
  Future<Either<Failure, List<ImportPaket>>> call(NoParams params) async {
    speicher.leseAufrufe++;
    return Right(speicher.pakete);
  }
}

/// Verbucht wie der Dienst: vergibt `(höchste bekannte Nummer) + 1` und legt
/// das Paket vorn in die Historie.
class FakeNotiereImportPaket
    implements UseCase<ImportPaket, NotiereImportPaketParams> {
  final ImportPaketeSpeicher speicher;

  FakeNotiereImportPaket(this.speicher);

  @override
  Future<Either<Failure, ImportPaket>> call(
    NotiereImportPaketParams params,
  ) async {
    speicher.notiereAufrufe++;
    final fehler = speicher.fehlerBeimNotieren;
    if (fehler != null) return Left(LocalFailure(message: fehler));
    final hoechste = speicher.pakete.isEmpty
        ? 0
        : speicher.pakete.map((p) => p.nummer).reduce((a, b) => a > b ? a : b);
    final neu = ImportPaket(
      nummer: hoechste + 1,
      geholtAm: angelegt,
      anzahlOrdner: params.ordnernamen.length,
    );
    speicher.pakete = [neu, ...speicher.pakete];
    return Right(neu);
  }
}

/// Nimmt zurück wie der Dienst: entfernt die Zeile, ohne einen Ordner
/// anzurühren.
class FakeLoescheImportPaket
    implements UseCase<void, LoescheImportPaketParams> {
  final ImportPaketeSpeicher speicher;

  FakeLoescheImportPaket(this.speicher);

  @override
  Future<Either<Failure, void>> call(LoescheImportPaketParams params) async {
    speicher.loeschAufrufe++;
    final fehler = speicher.fehlerBeimLoeschen;
    if (fehler != null) return Left(LocalFailure(message: fehler));
    speicher.pakete = [
      for (final p in speicher.pakete)
        if (p.nummer != params.nummer) p,
    ];
    return Right(null);
  }
}

/// Zeichnet auf, was geschrieben wurde — ohne echtes Dateisystem.
class ArbeitspaketDateiSpeicher {
  int schreibAufrufe = 0;
  String? letzterPfad;
  Arbeitspaket? letztesPaket;
  String? fehlerBeimSchreiben;
}

class FakeSchreibeArbeitspaket
    implements UseCase<void, SchreibeArbeitspaketParams> {
  final ArbeitspaketDateiSpeicher speicher;

  FakeSchreibeArbeitspaket(this.speicher);

  @override
  Future<Either<Failure, void>> call(SchreibeArbeitspaketParams params) async {
    speicher.schreibAufrufe++;
    speicher.letzterPfad = params.pfad;
    speicher.letztesPaket = params.paket;
    final fehler = speicher.fehlerBeimSchreiben;
    if (fehler != null) return Left(LocalFailure(message: fehler));
    return Right(null);
  }
}

/// Bloc samt seinen Attrappen — die Tests prüfen an ihnen die Aufrufzahlen.
class MandantenTestaufbau {
  final MandantenSpeicher register;
  final ZaehlenderAktenScan getAkten;
  final FesteFaelle getFaelle;
  final OrdnerStatusSpeicher ordnerStatus;
  final ImportPaketeSpeicher paketeSpeicher;
  final ArbeitspaketDateiSpeicher arbeitspaketDatei;
  final FesteMandanten mandantenQuelle;
  final MandantenOverviewBloc bloc;

  MandantenTestaufbau._(
    this.register,
    this.getAkten,
    this.getFaelle,
    this.ordnerStatus,
    this.paketeSpeicher,
    this.arbeitspaketDatei,
    this.mandantenQuelle,
    this.bloc,
  );

  factory MandantenTestaufbau({
    List<Mandant> register = const [],
    List<Akte> akten = const [],
    List<Fall> faelle = const [],
    List<ImportPaket> importPakete = const [],
    String stammordner = 'C:/Akten',
  }) {
    final speicher = MandantenSpeicher([...register]);
    final scan = ZaehlenderAktenScan(akten);
    final faelleQuelle = FesteFaelle(faelle);
    final vermerke = OrdnerStatusSpeicher();
    final paketeSpeicher = ImportPaketeSpeicher(importPakete);
    final dateiSpeicher = ArbeitspaketDateiSpeicher();
    final mandantenQuelle = FesteMandanten(speicher);
    return MandantenTestaufbau._(
      speicher,
      scan,
      faelleQuelle,
      vermerke,
      paketeSpeicher,
      dateiSpeicher,
      mandantenQuelle,
      MandantenOverviewBloc(
        FesteMandantenSeite(speicher),
        FesteAktenOrdnernamen(speicher),
        scan,
        faelleQuelle,
        FesteOrdnerStatus(vermerke),
        FakeSetzeOrdnerStatus(vermerke),
        FakeLoeschen(),
        FakeVerknuepfen(speicher),
        FesteImportPakete(paketeSpeicher),
        mandantenQuelle,
        FesteKanzleiSettings(stammordner),
        FakeNotiereImportPaket(paketeSpeicher),
        FakeSchreibeArbeitspaket(dateiSpeicher),
        FakeLoescheImportPaket(paketeSpeicher),
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
