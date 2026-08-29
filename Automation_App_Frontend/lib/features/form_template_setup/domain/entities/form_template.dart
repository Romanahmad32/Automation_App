import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:equatable/equatable.dart';

class FormTemplate extends Equatable {
  final int id;
  final String templateName;
  final List<FieldData> fields;

  /// Pfad der Word-Datei **ohne** Auflistung (HGN-Sektion). Null, wenn für die
  /// Vorlage keine Version ohne Auflistung hinterlegt ist.
  final String? wordFilePathOhneAuflistung;

  /// Pfad der Word-Datei **mit** Auflistung (enthält {{Schadensaufstellung}}
  /// und löst im Wizard den Schritt für Schadenspositionen + RVG aus). Null,
  /// wenn für die Vorlage keine Version mit Auflistung hinterlegt ist.
  final String? wordFilePathMitAuflistung;

  const FormTemplate({
    required this.id,
    required this.templateName,
    required this.fields,
    this.wordFilePathOhneAuflistung,
    this.wordFilePathMitAuflistung,
  });

  /// True, wenn eine Version ohne Auflistung (HGN) verknüpft ist.
  bool get hasOhneAuflistung => wordFilePathOhneAuflistung != null;

  /// True, wenn eine Version mit Auflistung (Schadensaufstellung) verknüpft ist.
  bool get hasMitAuflistung => wordFilePathMitAuflistung != null;

  factory FormTemplate.fromJson(Map<String, dynamic> json) {
    final fields =
        (json['fields'] as List).map((e) => FieldData.fromJson(e)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    // Ein früherer Zweig hob hier Altbestände mit `wordFilePath` +
    // `hasSchadensaufstellung` auf die zwei getrennten Slots. Er war
    // unerreichbar: schon die Erst-Migration der Backend-Datenbank kennt nur
    // die getrennten Spalten, und dieses JSON kommt ausschließlich von dort.
    return FormTemplate(
      id: json['id'],
      templateName: json['templateName'],
      fields: fields,
      wordFilePathOhneAuflistung: json['wordFilePathOhneAuflistung'] as String?,
      wordFilePathMitAuflistung: json['wordFilePathMitAuflistung'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateName': templateName,
      'fields': fields.map((e) => e.toJson()).toList(),
      'wordFilePathOhneAuflistung': wordFilePathOhneAuflistung,
      'wordFilePathMitAuflistung': wordFilePathMitAuflistung,
    };
  }

  FormTemplate copyWith({
    String? templateName,
    List<FieldData>? fields,
    String? Function()? wordFilePathOhneAuflistung,
    String? Function()? wordFilePathMitAuflistung,
  }) {
    return FormTemplate(
      id: id,
      templateName: templateName ?? this.templateName,
      fields: fields ?? this.fields,
      wordFilePathOhneAuflistung: wordFilePathOhneAuflistung != null
          ? wordFilePathOhneAuflistung()
          : this.wordFilePathOhneAuflistung,
      wordFilePathMitAuflistung: wordFilePathMitAuflistung != null
          ? wordFilePathMitAuflistung()
          : this.wordFilePathMitAuflistung,
    );
  }

  @override
  List<Object?> get props => [
    id,
    templateName,
    fields,
    wordFilePathOhneAuflistung,
    wordFilePathMitAuflistung,
  ];
}
