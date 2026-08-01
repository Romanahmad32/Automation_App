import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/delete_form_template.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'form_template_overview_event.dart';

part 'form_template_overview_state.dart';

/// Bewusst ein Singleton: Die Vorlagenliste wird auf mehreren Seiten
/// (Verwaltung, Wizard-Dropdown) angezeigt, die durch den AutoTabsRouter
/// gleichzeitig am Leben sind. Eine gemeinsame Instanz hält sie konsistent.
@lazySingleton
class FormTemplateOverviewBloc
    extends Bloc<FormTemplateOverviewEvent, FormTemplateOverviewState> {
  final UseCase<List<FormTemplate>, NoParams> _getFormTemplates;
  final UseCase<void, DeleteFormTemplateParams> _deleteFormTemplate;

  FormTemplateOverviewBloc(this._getFormTemplates, this._deleteFormTemplate)
    : super(FormTemplateOverviewLoading()) {
    on<LoadFormTemplatesEvent>(_onLoadFormTemplatesEvent);
    on<SearchFormTemplatesEvent>(_onSearchFormTemplatesEvent);
    on<DeleteFormTemplateEvent>(_onDeleteFormTemplateEvent);
  }

  /// Behaelt den aktuellen Suchbegriff bei, falls bereits eine Liste geladen
  /// war (z. B. beim Neuladen nach Rueckkehr aus der Detailseite).
  String get _currentQuery => state is FormTemplateOverviewLoaded
      ? (state as FormTemplateOverviewLoaded).query
      : '';

  Future<void> _onLoadFormTemplatesEvent(
    LoadFormTemplatesEvent event,
    Emitter<FormTemplateOverviewState> emit,
  ) async {
    final previousQuery = _currentQuery;
    emit(FormTemplateOverviewLoading());
    final result = await _getFormTemplates(NoParams());
    switch (result) {
      case Right(value: final formTemplates):
        emit(FormTemplateOverviewLoaded(formTemplates, query: previousQuery));
        break;
      case Left(value: final failure):
        emit(FormTemplateOverviewError(failure.message));
        break;
    }
  }

  void _onSearchFormTemplatesEvent(
    SearchFormTemplatesEvent event,
    Emitter<FormTemplateOverviewState> emit,
  ) {
    final currentState = state;
    if (currentState is FormTemplateOverviewLoaded) {
      emit(
        FormTemplateOverviewLoaded(
          currentState.formTemplates,
          query: event.query,
        ),
      );
    }
  }

  Future<void> _onDeleteFormTemplateEvent(
    DeleteFormTemplateEvent event,
    Emitter<FormTemplateOverviewState> emit,
  ) async {
    final result = await _deleteFormTemplate(
      DeleteFormTemplateParams(event.templateId),
    );
    switch (result) {
      case Right(value: final _):
        final currentState = state as FormTemplateOverviewLoaded;
        final newTemplates = currentState.formTemplates
            .where((element) => element.id != event.templateId)
            .toList();
        emit(
          FormTemplateOverviewLoaded(newTemplates, query: currentState.query),
        );
        break;
      case Left(value: final failure):
        emit(FormTemplateOverviewError(failure.message));
        break;
    }
  }
}
