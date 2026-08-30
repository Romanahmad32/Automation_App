import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/delete_mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_faelle.dart';
import 'package:automation_app/features/mandanten/domain/usecases/setze_ordner_status.dart';
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'mandanten_overview_event.dart';
part 'mandanten_overview_state.dart';

/// Lädt das Mandantenregister und den Akten-Scan und führt beides zusammen:
/// Mandanten mit ihren zugeordneten Akten sowie die noch nicht zugeordneten
/// Ordner für die manuelle Zuordnung.
///
/// Der Scan ist flach — die Fälle einer Akte kommen über [LadeFaelleEvent]
/// nach. Und jede Änderung am Register schreibt den Zustand fort, statt neu zu
/// scannen: bei rund 4000 Ordnern wäre ein Rescan nach jeder einzelnen
/// Zuordnung die Seite, die nach jedem Klick stehenbleibt.
@injectable
class MandantenOverviewBloc
    extends Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  final UseCase<List<Mandant>, NoParams> _getMandanten;
  final UseCase<List<Akte>, NoParams> _getAkten;
  final UseCase<List<Fall>, GetFaelleParams> _getFaelle;
  final UseCase<List<OrdnerStatus>, NoParams> _getOrdnerStatus;
  final UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams> _setzeOrdnerStatus;
  final UseCase<void, DeleteMandantParams> _deleteMandant;
  final UseCase<Mandant, VerknuepfeOrdnerParams> _verknuepfeOrdner;

  MandantenOverviewBloc(
    this._getMandanten,
    this._getAkten,
    this._getFaelle,
    this._getOrdnerStatus,
    this._setzeOrdnerStatus,
    this._deleteMandant,
    this._verknuepfeOrdner,
  ) : super(MandantenOverviewLoading()) {
    on<LoadMandantenUebersichtEvent>(_onLoad);
    on<SearchMandantenEvent>(_onSearch);
    on<SetzeZuordnungFilterEvent>(_onSetzeFilter);
    on<LadeFaelleEvent>(_onLadeFaelle);
    on<SetzeOrdnerStatusEvent>(_onSetzeOrdnerStatus);
    on<DeleteMandantEvent>(_onDelete);
    on<VerknuepfeOrdnerEvent>(_onVerknuepfe);
  }

  Future<void> _onLoad(
    LoadMandantenUebersichtEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final vorher = state;
    if (vorher is MandantenOverviewLoaded) {
      // Den bisherigen Stand stehen lassen und nur „lädt" markieren: ein
      // Spinner statt der Liste würde Scrollstand und Filter verwerfen.
      emit(vorher.copyWith(neuLadend: true));
    } else {
      emit(MandantenOverviewLoading());
    }

    final mandantenResult = await _getMandanten(const NoParams());
    final List<Mandant> mandanten;
    switch (mandantenResult) {
      case Right(value: final m):
        mandanten = m;
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
        return;
    }

    // Die Vermerke liegen in derselben Datenbank wie das Register und kosten
    // einen Abruf — sie kommen deshalb auch beim reinen Registerlauf mit.
    // Scheitert er, bleibt der bisherige Stand stehen: ein verlorener Vermerk
    // würde einen entschiedenen Ordner still zurück in den Stapel werfen.
    final statusResult = await _getOrdnerStatus(const NoParams());
    final ordnerStatus = switch (statusResult) {
      Right(value: final s) => s,
      Left() =>
        vorher is MandantenOverviewLoaded
            ? vorher.ordnerStatus
            : const <OrdnerStatus>[],
    };

    if (event.nurRegister && vorher is MandantenOverviewLoaded) {
      emit(
        vorher.copyWith(
          mandanten: mandanten,
          ordnerStatus: ordnerStatus,
          neuLadend: false,
        ),
      );
      return;
    }

    // Der Akten-Scan darf fehlschlagen (z. B. kein Stammordner) ohne die ganze
    // Seite zu blockieren — dann werden nur keine Akten angezeigt.
    final aktenResult = await _getAkten(const NoParams());
    final akten = switch (aktenResult) {
      Right(value: final a) => a,
      Left() => const <Akte>[],
    };

    emit(
      MandantenOverviewLoaded(
        mandanten: mandanten,
        akten: akten,
        ordnerStatus: ordnerStatus,
        query: vorher is MandantenOverviewLoaded ? vorher.query : '',
        zuordnungFilter: vorher is MandantenOverviewLoaded
            ? vorher.zuordnungFilter
            : const ZuordnungFilter(),
      ),
    );
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
    switch (result) {
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
      case Right(value: final stand):
        final aktuell = state;
        if (aktuell is! MandantenOverviewLoaded) return;
        emit(aktuell.copyWith(ordnerStatus: stand));
    }
  }

  void _onSearch(
    SearchMandantenEvent event,
    Emitter<MandantenOverviewState> emit,
  ) {
    final current = state;
    if (current is MandantenOverviewLoaded) {
      emit(current.copyWith(query: event.query));
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
    switch (result) {
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
      case Right():
        final aktuell = state;
        if (aktuell is! MandantenOverviewLoaded) return;
        // Der Mandant fällt raus, seine Ordner rutschen dadurch von selbst
        // zurück in den Zuordnungsstapel — ohne erneuten Scan.
        emit(
          aktuell.copyWith(
            mandanten: [
              for (final m in aktuell.mandanten)
                if (m.id != event.mandantId) m,
            ],
          ),
        );
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
    switch (result) {
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
      case Right(value: final aktualisiert):
        final aktuell = state;
        if (aktuell is! MandantenOverviewLoaded) return;
        // Der Ordner steht jetzt am Mandanten und verschwindet damit aus dem
        // Stapel: ein Austausch in der Liste genügt, kein Rescan.
        emit(
          aktuell.copyWith(
            mandanten: [
              for (final m in aktuell.mandanten)
                if (m.id == aktualisiert.id) aktualisiert else m,
            ],
          ),
        );
    }
  }
}
