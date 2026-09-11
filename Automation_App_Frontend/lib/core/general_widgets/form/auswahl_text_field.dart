import 'package:automation_app/core/general_widgets/form/auswahl_dialog.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Texteingabefeld mit Auswahlhilfe: primär getippt, das Symbol rechts öffnet
/// die Liste der bekannten Werte.
///
/// Gebaut wie `GermanDateField` und aus demselben Grund: Der Dialog ist ein
/// **Angebot**, kein Zwang. Ein Dropdown an dieser Stelle wäre das Gegenteil —
/// es liesse nur zu, was die App schon kennt, und der erste Wert daneben
/// (ein Fahrzeug, das im Register noch nicht steht) hätte keinen Weg mehr ins
/// Feld.
///
/// Arbeitet auf einem `FormControl<String>`. Die Formatprüfung gehört **nicht**
/// hierher: Sie wird beim Aufbau der FormGroup am Control registriert und ihre
/// Meldung über [validationMessages] hereingegeben — so wie das Datumsfeld es
/// mit `GermanDateField.validator` hält.
///
/// Umgeschrieben wird nichts: Was getippt oder im Dialog eingetragen wurde,
/// steht so im Control. Bis zum 11.09.2026 konnte ein Aufrufer hier einen
/// Normalisierer einhängen; sein einziger Nutzer, das Kennzeichen, übernimmt
/// Werte seitdem, wie sie eingegeben wurden (§4.2).
class AuswahlTextField extends StatelessWidget {
  final String formControlName;
  final String? labelText;
  final String? helperText;

  /// Über wie viele Zeilen [helperText] laufen darf. Ohne Angabe gilt die
  /// Vorgabe von Material (eine Zeile, danach „…") — in schmalen Spalten ist
  /// das zu wenig, dort gehören 2 hin.
  final int? helperMaxLines;

  /// Schrift des [helperText]. Ohne Angabe die Vorgabe des Themes; gesetzt
  /// wird sie dort, wo der Hilfetext gerade ein **Hinweis** ist und auffallen
  /// soll, ohne die Fehlerfarbe zu beanspruchen (`KennzeichenField`).
  final TextStyle? helperStyle;

  final Map<String, String Function(Object)>? validationMessages;

  /// Die Werte, die zur Wahl stehen. **Leer heißt: kein Symbol** — ein Knopf,
  /// der einen Dialog ohne Kandidaten öffnet, verspricht Hilfe und liefert
  /// eine leere Liste.
  final List<AuswahlKandidat> kandidaten;

  /// Überschrift des Auswahldialogs, z. B. „Kennzeichen wählen".
  final String dialogTitel;

  const AuswahlTextField({
    super.key,
    required this.formControlName,
    required this.kandidaten,
    required this.dialogTitel,
    this.labelText,
    this.helperText,
    this.helperMaxLines,
    this.helperStyle,
    this.validationMessages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveTextField<String>(
      formControlName: formControlName,
      keyboardType: TextInputType.text,
      validationMessages: validationMessages,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
        helperStyle: helperStyle,
        border: theme.inputDecorationTheme.border ?? const OutlineInputBorder(),
        suffixIcon: kandidaten.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'Aus bekannten Werten wählen',
                onPressed: () => _waehle(context),
              ),
      ),
    );
  }

  Future<void> _waehle(BuildContext context) async {
    // Das Control **vor** dem Dialog greifen: Danach ist der [context] dieses
    // Felds womöglich nicht mehr montiert, und `ReactiveForm.of` würde ins
    // Leere greifen.
    final form = ReactiveForm.of(context, listen: false) as FormGroup;
    final control = form.control(formControlName) as FormControl<String>;

    final gewaehlt = await AuswahlDialog.zeige(
      context,
      titel: dialogTitel,
      kandidaten: kandidaten,
    );
    if (gewaehlt == null) return;

    control.value = gewaehlt;
    // Sonst zeigt ein gewählter, aber ungültiger Wert seinen Fehler erst, wenn
    // das Feld auch noch angefasst wurde.
    control.markAsTouched();
  }
}
