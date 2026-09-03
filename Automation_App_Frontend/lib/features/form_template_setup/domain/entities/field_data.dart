import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
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

  /// Um wie viel ein **Datumsfeld** vorbelegt wird (§5.3). Nur für
  /// [InputType.date] von Belang.
  ///
  /// Die Unterscheidung ist bewusst dreiwertig, und beide Fälle sehen im
  /// Formular gleich aus, meinen aber Verschiedenes:
  ///
  /// * **`null` = nie angefasst.** Dann gilt die Namensregel
  ///   ([DatumsVorbelegung.ausFeldname]) — die Zusage an Bestandsvorlagen, in
  ///   denen `{{Zahlungsfrist}}` seine 5 Wochen weiter bekommt, ohne dass
  ///   jemand sie nachträgt.
  /// * **Lauter Nullen = bewusst heute.** Der Anwalt hat entschieden, dass
  ///   dieses Feld mit dem heutigen Datum vorbelegt wird; die Namensregel
  ///   bleibt dann außen vor. Ohne diese Unterscheidung liesse sich die
  ///   Ableitung an einem Feld namens „Frist" nie abschalten.
  final DatumsVorbelegung? vorbelegung;

  const FieldData({
    required this.order,
    required this.label,
    required this.required,
    required this.inputType,
    this.datenquelle = FeldDatenquelle.keine,
    this.vorbelegung,
  });

  /// [vorbelegung] fehlt hier absichtlich: `null` wäre nicht von „nicht
  /// angegeben" zu unterscheiden, ein Zurücksetzen also unmöglich. Sie wird
  /// unverändert durchgereicht — zum Setzen und Löschen gibt es
  /// [mitVorbelegung].
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
      vorbelegung: vorbelegung,
    );
  }

  /// Setzt die Datums-Vorbelegung — oder nimmt sie mit `null` ganz weg, sodass
  /// wieder die Namensregel greift.
  FieldData mitVorbelegung(DatumsVorbelegung? vorbelegung) => FieldData(
    order: order,
    label: label,
    required: required,
    inputType: inputType,
    datenquelle: datenquelle,
    vorbelegung: vorbelegung,
  );

  factory FieldData.fromJson(Map<String, dynamic> json) {
    final rohVorbelegung = json['vorbelegung'];
    return FieldData(
      order: json['order'] as int,
      label: json['label'] as String,
      required: json['required'] as bool,
      inputType: InputType.fromValue(json['inputType'] as String),
      // Bestandsvorlagen ohne Feld → keine (fällt auf die Heuristik zurück).
      datenquelle: FeldDatenquelle.fromValue(json['datenquelle'] as String?),
      // Fehlt der Schlüssel (oder steht dort etwas anderes als ein Objekt),
      // bleibt es bei null — „nie angefasst", also Namensregel.
      vorbelegung: rohVorbelegung is Map<String, dynamic>
          ? DatumsVorbelegung.fromJson(rohVorbelegung)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'order': order,
    'label': label,
    'required': required,
    'inputType': inputType.value,
    'datenquelle': datenquelle.value,
    // Nur schreiben, wenn eingestellt: So bleibt eine Vorlage, an der nie eine
    // Vorbelegung gesetzt wurde, byteidentisch zu vorher — und ein
    // gespeicherter Schlüssel heisst umgekehrt immer „bewusst eingestellt".
    if (vorbelegung != null) 'vorbelegung': vorbelegung!.toJson(),
  };
}
