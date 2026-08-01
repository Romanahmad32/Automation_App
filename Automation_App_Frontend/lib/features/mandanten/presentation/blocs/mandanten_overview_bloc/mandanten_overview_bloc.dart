import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/delete_mandant.dart';
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'mandanten_overview_event.dart';
part 'mandanten_overview_state.dart';

/// Lädt das Mandantenregister und den Akten-Scan und führt beides zusammen:
/// Mandanten mit ihren zugeordneten Akten sowie die noch nicht zugeordneten
/// Ordner für die manuelle Zuordnung.
@injectable
class MandantenOverviewBloc
    extends Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  final UseCase<List<Mandant>, NoParams> _getMandanten;
  final UseCase<List<Akte>, NoParams> _getAkten;
  final UseCase<void, DeleteMandantParams> _deleteMandant;
  final UseCase<Mandant, VerknuepfeOrdnerParams> _verknuepfeOrdner;

  MandantenOverviewBloc(
    this._getMandanten,
    this._getAkten,
    this._deleteMandant,
    this._verknuepfeOrdner,
  ) : super(MandantenOverviewLoading()) {
    on<LoadMandantenUebersichtEvent>(_onLoad);
    on<SearchMandantenEvent>(_onSearch);
    on<DeleteMandantEvent>(_onDelete);
    on<VerknuepfeOrdnerEvent>(_onVerknuepfe);
  }

  String get _currentQuery => state is MandantenOverviewLoaded
      ? (state as MandantenOverviewLoaded).query
      : '';

  Future<void> _onLoad(
    LoadMandantenUebersichtEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final previousQuery = _currentQuery;
    emit(MandantenOverviewLoading());

    final mandantenResult = await _getMandanten(const NoParams());
    final List<Mandant> mandanten;
    switch (mandantenResult) {
      case Right(value: final m):
        mandanten = m;
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
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
        query: previousQuery,
      ),
    );
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

  Future<void> _onDelete(
    DeleteMandantEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final result = await _deleteMandant(DeleteMandantParams(event.mandantId));
    switch (result) {
      case Right():
        add(LoadMandantenUebersichtEvent());
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
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
      case Right():
        add(LoadMandantenUebersichtEvent());
      case Left(value: final failure):
        emit(MandantenOverviewError(failure.message));
    }
  }
}
