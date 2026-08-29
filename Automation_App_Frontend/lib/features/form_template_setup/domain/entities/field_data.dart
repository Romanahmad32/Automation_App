import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';

class FieldData {
  final int order;
  final String label;
  final bool required;
  final InputType inputType;

  /// Woraus dieses Feld beim Ausfüllen vorbelegt wird. [FeldDatenquelle.keine]
  /// = keine feste Zuordnung (dann greift die Namens-Heuristik).
  final FeldDatenquelle datenquelle;

  const FieldData({
    required this.order,
    required this.label,
    required this.required,
    required this.inputType,
    this.datenquelle = FeldDatenquelle.keine,
  });

  FieldData copyWith({
    int? order,
    String? label,
    bool? required,
    InputType? inputType,
    FeldDatenquelle? datenquelle,
  }) {
    return FieldData(
      order: order ?? this.order,
      label: label ?? this.label,
      required: required ?? this.required,
      inputType: inputType ?? this.inputType,
      datenquelle: datenquelle ?? this.datenquelle,
    );
  }

  factory FieldData.fromJson(Map<String, dynamic> json) {
    return FieldData(
      order: json['order'] as int,
      label: json['label'] as String,
      required: json['required'] as bool,
      inputType: InputType.fromValue(json['inputType'] as String),
      // Bestandsvorlagen ohne Feld → keine (fällt auf die Heuristik zurück).
      datenquelle: FeldDatenquelle.fromValue(json['datenquelle'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'order': order,
    'label': label,
    'required': required,
    'inputType': inputType.value,
    'datenquelle': datenquelle.value,
  };
}
