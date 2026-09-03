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
class AuswahlTextField extends StatelessWidget {
  final String formControlName;
  final String? labelText;
  final String? helperText;

  /// Über wie viele Zeilen [helperText] laufen darf. Ohne Angabe gilt die
  /// Vorgabe von Material (eine Zeile, danach „…") — in schmalen Spalten ist
  /// das zu wenig, dort gehören 2 hin.
  final int? helperMaxLines;

  final Map<String, String Function(Object)>? validationMessages;

  /// Die Werte, die zur Wahl stehen. **Leer heißt: kein Symbol** — ein Knopf,
  /// der einen Dialog ohne Kandidaten öffnet, verspricht Hilfe und liefert
  /// eine leere Liste.
  final List<AuswahlKandidat> kandidaten;

  /// Überschrift des Auswahldialogs, z. B. „Kennzeichen wählen".
  final String dialogTitel;

  /// Wird auf die freie Eingabe im Dialog angewandt (siehe [AuswahlDialog]).
  final String Function(String)? normalisiere;

  const AuswahlTextField({
    super.key,
    required this.formControlName,
    required this.kandidaten,
    required this.dialogTitel,
    this.labelText,
    this.helperText,
    this.helperMaxLines,
    this.validationMessages,
    this.normalisiere,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feld = ReactiveTextField<String>(
      formControlName: formControlName,
      keyboardType: TextInputType.text,
      validationMessages: validationMessages,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
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

    if (normalisiere == null) return feld;

    // Erst beim Verlassen des Felds normalisieren, nicht bei jedem
    // Tastendruck: Der Cursor säße mitten in einem Wert, der sich unter ihm
    // umformt, und eine noch halbfertige Eingabe (`HGE14`) würde vom
    // Normalisierer zerlegt, bevor der Anwalt sie zu Ende getippt hat.
    return Focus(
      onFocusChange: (hatFokus) {
        if (!hatFokus) _normalisiereGetipptenWert(context);
      },
      child: feld,
    );
  }

  /// Übernimmt [normalisiere] auf einen direkt getippten (nicht über den
  /// Dialog gewählten) Wert, sobald das Feld den Fokus verliert.
  void _normalisiereGetipptenWert(BuildContext context) {
    final form = ReactiveForm.of(context, listen: false) as FormGroup;
    final control = form.control(formControlName) as FormControl<String>;

    final wert = control.value;
    if (wert == null || wert.isEmpty) return;

    final normalisiert = normalisiere!(wert);
    // Nur zurückschreiben, wenn sich etwas ändert — sonst löst das Control
    // ein `valueChanges`-Ereignis ohne fachlichen Anlass aus.
    if (normalisiert != wert) {
      control.value = normalisiert;
    }
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
      normalisiere: normalisiere,
    );
    if (gewaehlt == null) return;

    control.value = gewaehlt;
    // Sonst zeigt ein gewählter, aber ungültiger Wert seinen Fehler erst, wenn
    // das Feld auch noch angefasst wurde.
    control.markAsTouched();
  }
}
