import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'template_placeholders_event.dart';
part 'template_placeholders_state.dart';

/// Lädt die in den verknüpften Word-Dateien erkannten {{Platzhalter}} — getrennt
/// für die Version ohne und mit Auflistung —, damit der Anwender die
/// Eingabefelder der Vorlage daran ausrichten kann.
@injectable
class TemplatePlaceholdersBloc
    extends Bloc<TemplatePlaceholdersEvent, TemplatePlaceholdersState> {
  final UseCase<List<String>, GetTemplatePlaceholdersParams>
  _getTemplatePlaceholders;

  TemplatePlaceholdersBloc(this._getTemplatePlaceholders)
    : super(const TemplatePlaceholdersState()) {
    on<LoadTemplatePlaceholders>(_onLoadTemplatePlaceholders);
    on<ClearTemplatePlaceholders>(_onClearTemplatePlaceholders);
  }

  Future<void> _onLoadTemplatePlaceholders(
    LoadTemplatePlaceholders event,
    Emitter<TemplatePlaceholdersState> emit,
  ) async {
    emit(state.withSlot(event.slot, const SlotPlaceholdersLoading()));
    final result = await _getTemplatePlaceholders(
      GetTemplatePlaceholdersParams(event.wordFilePath),
    );
    switch (result) {
      case Right(value: final placeholders):
        emit(state.withSlot(event.slot, SlotPlaceholdersLoaded(placeholders)));
      case Left(value: final failure):
        emit(
          state.withSlot(event.slot, SlotPlaceholdersError(failure.message)),
        );
    }
  }

  void _onClearTemplatePlaceholders(
    ClearTemplatePlaceholders event,
    Emitter<TemplatePlaceholdersState> emit,
  ) {
    emit(state.withSlot(event.slot, const SlotPlaceholdersInitial()));
  }
}
