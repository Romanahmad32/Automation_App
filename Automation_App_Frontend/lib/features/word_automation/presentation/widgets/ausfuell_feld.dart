import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_text_field.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/word_automation/domain/services/datenquelle_vorschlaege.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ein Eingabefeld des Ausfüllschritts — die Fabrik, die aus einem
/// [FieldData] das passende Widget macht.
///
/// Eigenes Widget und nicht mehr eine Methode des `FormTemplateBuilder`: Der
/// entscheidet über die FormGroup (Schlüssel, Werte, Validatoren), dieses hier
/// über das Aussehen einer Zeile. Die Trennung erlaubt auch, ein Feld einzeln zu
/// prüfen, statt jedes Mal ein ganzes Formular aufzubauen.
///
/// **Die Validatoren stehen nicht hier.** Sie werden am Control registriert,
/// wo die FormGroup entsteht; dieses Widget liefert nur ihre Meldungen. Läge
/// die Prüfung am Widget, gälte sie nicht mehr für ein eingeklapptes Feld
/// (#82) — und ein unsichtbarer Fehler sperrt den Knopf ohne erkennbaren Grund.
class AusfuellFeld extends StatelessWidget {
  final FieldData field;

  /// Hinweiszeile unter dem Feld (Pflichtmarkierung, Herkunft der Vorbelegung).
  final String? helperText;
  final int? helperMaxLines;

  final Map<String, String Function(Object)> validationMessages;

  /// Bekannte Werte für dieses Feld (#17). Leer heißt: keine Auswahlhilfe.
  ///
  /// **Sie hängen an der Datenquelle, nicht am Feldtyp** — deshalb bekommt auch
  /// ein gewöhnliches Textfeld die Auswahl, sobald zu seiner Quelle mehrere
  /// Werte bekannt sind.
  final List<FeldVorschlag> vorschlaege;

  const AusfuellFeld({
    super.key,
    required this.field,
    this.helperText,
    this.helperMaxLines,
    this.validationMessages = const {},
    this.vorschlaege = const [],
  });

  @override
  Widget build(BuildContext context) {
    switch (field.inputType) {
      case InputType.date:
        // Direkt tippbar (Format prüft GermanDateField.validator);
        // das Kalender-Icon öffnet zusätzlich den Auswahl-Dialog.
        return GermanDateField(
          formControlName: field.label,
          labelText: field.label,
          helperText: helperText,
          helperMaxLines: helperMaxLines,
          validationMessages: validationMessages,
        );
      case InputType.kennzeichen:
        // Derselbe Baustein wie beim Erfassen des Mandats: Prüfung, Meldung
        // und die Schreibweise `HG-E 1427` stehen genau einmal im Projekt.
        return KennzeichenField(
          formControlName: field.label,
          labelText: field.label,
          helperText: helperText,
          helperMaxLines: helperMaxLines,
          validationMessages: validationMessages,
          kandidaten: _kandidaten,
        );
      case InputType.integer:
        return GeneralTextField<String>(
          formControlName: field.label,
          labelText: field.label,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validationMessages: validationMessages,
          inputDecoration: _decoration,
        );
      case InputType.decimal:
        return GeneralTextField<String>(
          formControlName: field.label,
          labelText: field.label,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validationMessages: validationMessages,
          inputDecoration: _decoration,
        );
      case InputType.text:
        // Ohne bekannte Werte bleibt es das gewöhnliche Textfeld: ein Symbol,
        // das eine leere Liste öffnet, ist schlechter als keines.
        if (vorschlaege.isEmpty) {
          return GeneralTextField<String>(
            formControlName: field.label,
            labelText: field.label,
            keyboardType: TextInputType.text,
            validationMessages: validationMessages,
            inputDecoration: _decoration,
          );
        }
        return _auswahlFeld(
          titel: '„${field.label}" wählen',
          meldungen: validationMessages,
        );
    }
  }

  /// Das Textfeld mit Auswahlhilfe, mit den Kandidaten dieses Felds.
  Widget _auswahlFeld({
    required String titel,
    required Map<String, String Function(Object)> meldungen,
  }) => AuswahlTextField(
    formControlName: field.label,
    labelText: field.label,
    helperText: helperText,
    helperMaxLines: helperMaxLines,
    validationMessages: meldungen,
    kandidaten: _kandidaten,
    dialogTitel: titel,
  );

  /// Die bekannten Werte dieses Felds als Kandidaten des Auswahldialogs; die
  /// Herkunftszeile kommt aus der Datenquelle des Vorschlags.
  List<AuswahlKandidat> get _kandidaten => [
    for (final vorschlag in vorschlaege)
      AuswahlKandidat(vorschlag.wert, vorschlag.herkunft.beschreibung),
  ];

  InputDecoration get _decoration =>
      InputDecoration(helperText: helperText, helperMaxLines: helperMaxLines);
}
