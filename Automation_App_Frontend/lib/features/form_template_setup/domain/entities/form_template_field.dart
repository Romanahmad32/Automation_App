import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';

class FormTemplateField {
  final String name;
  final InputType inputType;

  FormTemplateField({required this.name, required this.inputType});

  FormTemplateField copyWith({String? name, InputType? inputType}) {
    return FormTemplateField(
      name: name ?? this.name,
      inputType: inputType ?? this.inputType,
    );
  }
}
