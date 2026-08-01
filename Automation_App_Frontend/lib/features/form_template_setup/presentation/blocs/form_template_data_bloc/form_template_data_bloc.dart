import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'form_template_data_event.dart';

part 'form_template_data_state.dart';

@injectable
class FormTemplateDataBloc
    extends Bloc<FormTemplateDataEvent, FormTemplateDataState> {
  final UseCase<void, CreateFormTemplateRequest> _createFormTemplate;

  final UseCase<FormTemplate, UpdateFormTemplateParams> _updateFormTemplate;

  FormTemplateDataBloc(this._createFormTemplate, this._updateFormTemplate)
      : super(FormTemplateDataIdle()) {
    on<SubmitFormTemplateDataEvent>(_onSubmitFormTemplateDataEvent);
  }

  Future<void> _onSubmitFormTemplateDataEvent(SubmitFormTemplateDataEvent event,
      Emitter<FormTemplateDataState> emit,) async {
    emit(SubmittingFormTemplateData());
    Either<Failure, void> result;
    if (event.existingItemId == null) {
      result = await _createFormTemplate(
        CreateFormTemplateRequest(
          templateName: event.templateName!,
          fields: event.formData,
          wordFilePathOhneAuflistung: event.wordFilePathOhneAuflistung,
          wordFilePathMitAuflistung: event.wordFilePathMitAuflistung,
        ),
      );
    } else {
      result = await _updateFormTemplate(
        UpdateFormTemplateParams(
          FormTemplate(
            id: event.existingItemId!,
            templateName: event.templateName ?? '',
            fields: event.formData,
            wordFilePathOhneAuflistung: event.wordFilePathOhneAuflistung,
            wordFilePathMitAuflistung: event.wordFilePathMitAuflistung,
          ),
        ),
      );
    }
    switch (result) {
      case Right():
        await Future.delayed(Duration(milliseconds: 200));
        emit(FormTemplateDataSuccess());
        emit(FormTemplateDataIdle());
      case Left(value: final failure):
        emit(FormTemplateDataError(failure.message));
    }
  }
}
