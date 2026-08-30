import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/usecases/delete_mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_faelle.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/usecases/setze_ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'mandanten_overview_event.dart';
part 'mandanten_overview_state.dart';
part 'mandanten_stand_abruf.dart';

/// Lädt das Mandantenregister und den Akten-Scan und führt beides zusammen:
/// Mandanten mit ihren zugeordneten Akten sowie die noch nicht zugeordneten
/// Ordner für die manuelle Zuordnung.
///
/// Drei Entscheidungen hängen an der Größenordnung — rund 4000 Ordner unter dem
/// Stammordner und in der Kanzlei ebenso viele Mandanten:
///
/// * Der Scan ist flach; die Fälle einer Akte kommen über [LadeFaelleEvent]
///   nach.
/// * Die Mandantenliste kommt seitenweise ([seitenGroesse] je Abruf), und die
///   Suche darüber läuft im Dienst über den ganzen Bestand.
/// * Jede Änderung am Register schreibt den Zustand fort, statt neu zu scannen:
///   ein Rescan nach jeder einzelnen Zuordnung wäre die Seite, die nach jedem
///   Klick stehenbleibt.
///
/// Was beim Laden zusammengetragen wird, steht in [MandantenStandAbruf]; was
/// eine Änderung aus dem Zustand macht, in [MandantenOverviewLoaded] selbst.
@injectable
class MandantenOverviewBloc
    extends Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  /// Wie viele Mandanten ein Abruf holt.
  static const int seitenGroesse = 50;

  /// Wie lange das Suchfeld wartet, bevor es den Bloc fragt. Die Wartezeit
  /// sitzt im `EntitySearchBar` und nicht als Bloc-Transformer hier: ein
  /// `restartable`/`droppable` aus `bloc_concurrency` lässt `close()` in der
  /// Teardown von Widget-Tests hängen.
  static const Duration sucheVerzoegerung = Duration(milliseconds: 250);

  final MandantenStandAbruf _abruf;
  final UseCase<List<Fall>, GetFaelleParams> _getFaelle;
  final UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams> _setzeOrdnerStatus;
  final UseCase<void, DeleteMandantParams> _deleteMandant;
  final UseCase<Mandant, VerknuepfeOrdnerParams> _verknuepfeOrdner;

  MandantenOverviewBloc(
    UseCase<MandantenSeite, MandantenSeiteParams> getMandantenSeite,
    UseCase<List<String>, NoParams> getAktenOrdnernamen,
    UseCase<List<Akte>, NoParams> getAkten,
    this._getFaelle,
    UseCase<List<OrdnerStatus>, NoParams> getOrdnerStatus,
    this._setzeOrdnerStatus,
    this._deleteMandant,
    this._verknuepfeOrdner,
  ) : _abruf = MandantenStandAbruf(
        getSeite: getMandantenSeite,
        getAktenOrdnernamen: getAktenOrdnernamen,
        getOrdnerStatus: getOrdnerStatus,
        getAkten: getAkten,
      ),
      super(MandantenOverviewLoading()) {
    on<LoadMandantenUebersichtEvent>(_onLoad);
    on<SearchMandantenEvent>(_onSearch);
    on<LadeWeitereMandantenEvent>(_onLadeWeitere);
    on<SetzeZuordnungFilterEvent>(_onSetzeFilter);
    on<LadeFaelleEvent>(_onLadeFaelle);
    on<SetzeOrdnerStatusEvent>(_onSetzeOrdnerStatus);
    on<FehlerVerwerfenEvent>(_onFehlerVerwerfen);
    on<DeleteMandantEvent>(_onDelete);
    on<VerknuepfeOrdnerEvent>(_onVerknuepfe);
  }

  Future<void> _onLoad(
    LoadMandantenUebersichtEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final vorher = state;
    final alt = vorher is MandantenOverviewLoaded ? vorher : null;
    if (alt != null) {
      // Den bisherigen Stand stehen lassen und nur „lädt" markieren: ein
      // Spinner statt der Liste würde Scrollstand und Filter verwerfen.
      emit(alt.copyWith(neuLadend: true, fehlerVerwerfen: true));
    } else {
      emit(MandantenOverviewLoading());
    }

    final result = await _abruf.lade(alt: alt, nurRegister: event.nurRegister);
    switch (result) {
      case Right(value: final stand):
        emit(stand);
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
    }
  }

  /// Sucht im Dienst über den ganzen Bestand und beginnt wieder bei der ersten
  /// Seite. Im Speicher zu filtern fände nur, was gerade geladen ist.
  Future<void> _onSearch(
    SearchMandantenEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    emit(
      aktuell.copyWith(
        query: event.query,
        neuLadend: true,
        fehlerVerwerfen: true,
      ),
    );

    final result = await _abruf.seite(
      suche: event.query,
      anzahl: seitenGroesse,
    );
    final jetzt = state;
    if (jetzt is! MandantenOverviewLoaded) return;
    // Zwei Suchen können sich überholen. Die Antwort auf einen Begriff, der
    // nicht mehr im Feld steht, ist keine Antwort mehr.
    if (jetzt.query != event.query) return;
    switch (result) {
      case Right(value: final seite):
        emit(jetzt.mitSeite(seite, jetzt.zugeordneteOrdnernamen));
      case Left(value: final failure):
        emit(jetzt.copyWith(neuLadend: false, fehler: failure.message));
    }
  }

  /// Hängt die nächste Seite an: es kommt etwas dazu, es wird nichts ersetzt.
  Future<void> _onLadeWeitere(
    LadeWeitereMandantenEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    // Der Scroll meldet sich Pixel für Pixel — ohne diese Sperre liefe je
    // Meldung ein Abruf, und dieselbe Seite käme mehrfach.
    if (aktuell.mehrLadend || !aktuell.gibtWeitereMandanten) return;
    emit(aktuell.copyWith(mehrLadend: true));

    final result = await _abruf.seite(
      suche: aktuell.query,
      ueberspringen: aktuell.mandanten.length,
      anzahl: seitenGroesse,
    );
    final jetzt = state;
    if (jetzt is! MandantenOverviewLoaded) return;
    switch (result) {
      case Right(value: final seite):
        emit(
          jetzt.mitSeite(seite, jetzt.zugeordneteOrdnernamen, anhaengen: true),
        );
      case Left(value: final failure):
        emit(jetzt.copyWith(mehrLadend: false, fehler: failure.message));
    }
  }

  /// Setzt oder nimmt den Vermerk zurück. Der Dienst antwortet mit dem
  /// vollständigen Stand danach — auch eine Massenaktion über hunderte Ordner
  /// bleibt damit ein Aufruf und ein Zustandswechsel, ohne Rescan.
  Future<void> _onSetzeOrdnerStatus(
    SetzeOrdnerStatusEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    if (event.ordnernamen.isEmpty) return;
    final result = await _setzeOrdnerStatus(
      SetzeOrdnerStatusParams(ordnernamen: event.ordnernamen, art: event.art),
    );
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        // Nur eine Meldung, nicht die Seite: den Scan über tausende Ordner,
        // Filter und Scrollstand für eine gescheiterte Aktion wegzuwerfen wäre
        // teurer als die Aktion selbst.
        emit(aktuell.copyWith(fehler: failure.message));
      case Right(value: final stand):
        emit(aktuell.copyWith(ordnerStatus: stand, fehlerVerwerfen: true));
    }
  }

  void _onFehlerVerwerfen(
    FehlerVerwerfenEvent event,
    Emitter<MandantenOverviewState> emit,
  ) {
    final aktuell = state;
    if (aktuell is MandantenOverviewLoaded) {
      emit(aktuell.copyWith(fehlerVerwerfen: true));
    }
  }

  void _onSetzeFilter(
    SetzeZuordnungFilterEvent event,
    Emitter<MandantenOverviewState> emit,
  ) {
    final current = state;
    if (current is MandantenOverviewLoaded) {
      emit(current.copyWith(zuordnungFilter: event.filter));
    }
  }

  /// Fälle einer Akte nachladen. Ein fehlgeschlagener Scan gilt als „keine
  /// Fälle": der Ordner kann seit dem Scan umbenannt worden sein, und dafür
  /// die ganze Seite auf einen Fehler zu werfen wäre unverhältnismäßig.
  Future<void> _onLadeFaelle(
    LadeFaelleEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    if (event.akte.faelleGeladen) return;
    final result = await _getFaelle(GetFaelleParams(event.akte.pfad));
    final faelle = switch (result) {
      Right(value: final f) => f,
      Left() => const <Fall>[],
    };

    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    emit(
      aktuell.copyWith(
        akten: [
          for (final akte in aktuell.akten)
            if (akte.pfad == event.akte.pfad) akte.mitFaellen(faelle) else akte,
        ],
      ),
    );
  }

  Future<void> _onDelete(
    DeleteMandantEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final result = await _deleteMandant(DeleteMandantParams(event.mandantId));
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        emit(aktuell.copyWith(fehler: failure.message));
      case Right():
        emit(aktuell.ohneMandant(event.mandantId));
    }
  }

  Future<void> _onVerknuepfe(
    VerknuepfeOrdnerEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final result = await _verknuepfeOrdner(
      VerknuepfeOrdnerParams(
        mandantId: event.mandantId,
        ordnername: event.ordnername,
      ),
    );
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        emit(aktuell.copyWith(fehler: failure.message));
      case Right(value: final aktualisiert):
        emit(aktuell.mitZuordnung(aktualisiert, event.ordnername));
    }
  }
}
