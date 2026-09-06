import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:equatable/equatable.dart';

class FormTemplate extends Equatable {
  final int id;
  final String templateName;
  final List<FieldData> fields;

  /// Was der Editor beim letzten Speichern über die Vollständigkeit
  /// festgehalten hat (#104 Stufe 4) — `null` heißt **unbekannt**: eine
  /// Vorlage aus der Zeit davor, oder eine, deren Felder/Dateien sich seither
  /// geändert haben, ohne dass jemand neu gerechnet hätte (siehe [copyWith]).
  ///
  /// Er reist in der opaken `fields`-Spalte mit; Einzelheiten der Form stehen
  /// in [GespeicherterStand].
  final GespeicherterStand? stand;

  /// Pfad der Word-Datei **ohne** Auflistung (HGn-Sektion). Null, wenn für die
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
    this.stand,
  });

  /// True, wenn eine Version ohne Auflistung (HGn) verknüpft ist.
  bool get hasOhneAuflistung => wordFilePathOhneAuflistung != null;

  /// True, wenn eine Version mit Auflistung (Schadensaufstellung) verknüpft ist.
  bool get hasMitAuflistung => wordFilePathMitAuflistung != null;

  factory FormTemplate.fromJson(Map<String, dynamic> json) {
    // Die `fields`-Spalte trägt seit #104 Stufe 4 zwei Formen: die nackte
    // Feldliste (Bestand) und ein Objekt aus Feldliste plus Stand.
    // [GespeicherterStand] kennt beide — hier wird nicht danach gefragt.
    final rohFelder = json['fields'];
    final fields =
        GespeicherterStand.felderAus(
            rohFelder,
          ).map((e) => FieldData.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    // Ein früherer Zweig hob hier Altbestände mit `wordFilePath` +
    // `hasSchadensaufstellung` auf die zwei getrennten Slots. Er war
    // unerreichbar: schon die Erst-Migration der Backend-Datenbank kennt nur
    // die getrennten Spalten, und dieses JSON kommt ausschließlich von dort.
    return FormTemplate(
      id: json['id'] as int,
      templateName: json['templateName'] as String,
      fields: fields,
      wordFilePathOhneAuflistung: json['wordFilePathOhneAuflistung'] as String?,
      wordFilePathMitAuflistung: json['wordFilePathMitAuflistung'] as String?,
      stand: GespeicherterStand.lesen(rohFelder),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateName': templateName,
      'fields': GespeicherterStand.verpacke([
        for (final feld in fields) feld.toJson(),
      ], stand),
      'wordFilePathOhneAuflistung': wordFilePathOhneAuflistung,
      'wordFilePathMitAuflistung': wordFilePathMitAuflistung,
    };
  }

  /// **Der Stand fällt weg, sobald seine Grundlage sich ändert.** Wer [fields]
  /// oder einen Word-Pfad austauscht, hat eine andere Vorlage vor sich als die,
  /// über die der Editor geurteilt hat — die alte Zusage „vollständig" wäre
  /// dann eine Behauptung. Die Übersicht sagt danach „Noch nicht geprüft", bis
  /// jemand die Vorlage wieder im Editor speichert. Wer den neuen Stand kennt,
  /// gibt ihn über [stand] ausdrücklich mit.
  ///
  /// Betroffen sind die beiden Griffe aus „Word Automation" (`WizardCubit
  /// .aktualisiereFeld`, `.linkWordFileToTemplate`): Sie ändern Felder bzw.
  /// eine Datei, ohne die Platzhalter beider Dateien zu kennen.
  FormTemplate copyWith({
    String? templateName,
    List<FieldData>? fields,
    String? Function()? wordFilePathOhneAuflistung,
    String? Function()? wordFilePathMitAuflistung,
    GespeicherterStand? Function()? stand,
  }) {
    final grundlageGeaendert =
        fields != null ||
        wordFilePathOhneAuflistung != null ||
        wordFilePathMitAuflistung != null;
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
      stand: stand != null ? stand() : (grundlageGeaendert ? null : this.stand),
    );
  }

  @override
  List<Object?> get props => [
    id,
    templateName,
    fields,
    wordFilePathOhneAuflistung,
    wordFilePathMitAuflistung,
    stand,
  ];
}
