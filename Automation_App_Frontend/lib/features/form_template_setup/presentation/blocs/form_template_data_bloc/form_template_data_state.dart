part of 'form_template_data_bloc.dart';

sealed class FormTemplateDataState extends Equatable {
  const FormTemplateDataState();
}

final class FormTemplateDataIdle extends FormTemplateDataState {
  @override
  List<Object?> get props => [];
}

final class SubmittingFormTemplateData extends FormTemplateDataState {
  @override
  List<Object?> get props => [];
}

final class FormTemplateDataSuccess extends FormTemplateDataState {
  @override
  List<Object?> get props => [];
}

final class FormTemplateDataError extends FormTemplateDataState {
  final String message;

  const FormTemplateDataError(this.message);

  @override
  List<Object?> get props => [message];
}
