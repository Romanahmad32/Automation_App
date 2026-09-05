import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/datums_vorbelegung_editor.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_name_hinweis.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_badge.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

class TemplateFieldItem extends StatelessWidget {
  final int index;
  final FieldData fieldData;
  final ValueChanged<InputType?> onTypeChanged;
  final ValueChanged<FeldDatenquelle?> onDatenquelleChanged;
  final ValueChanged<bool?> onRequiredChanged;

  /// Die Datums-Vorbelegung des Felds wurde geändert (§5.3). Null nimmt die
  /// Einstellung zurück, sodass wieder die Namensregel greift.
  final ValueChanged<DatumsVorbelegung?> onVorbelegungChanged;

  final VoidCallback onDelete;

  /// Klick auf das Kennzeichen „in keiner Datei" — führt zur Zuordnung (#36).
  final VoidCallback? onZuordnen;

  const TemplateFieldItem({
    super.key,
    required this.index,
    required this.fieldData,
    required this.onTypeChanged,
    required this.onDatenquelleChanged,
    required this.onRequiredChanged,
    required this.onVorbelegungChanged,
    required this.onDelete,
    this.onZuordnen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(2.0),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(spacing: 10, children: _zeile(theme)),
          // Kennzeichen „beide · nur HGN · nur Auflistung · in keiner Datei"
          // (#35 Teil 3) — sagt, welches Schreiben dieses Feld braucht, und
          // führt bei „in keiner Datei" zur Zuordnung (#36).
          FeldVorkommenBadge(
            formControlName: fieldData.label,
            onZuordnen: onZuordnen,
          ),
          FeldNameHinweis(
            formControlName: fieldData.label,
            datenquelleGesetzt: fieldData.datenquelle.istGesetzt,
          ),
          // Eine Vorbelegung hat nur ein Datumsfeld (§5.3).
          if (fieldData.inputType == InputType.date) _vorbelegung(),
        ],
      ),
    );
  }

  /// Der Vorbelegungs-Einsteller unter der Feldzeile.
  ///
  /// Er hängt am **Wert** des Controls, nicht an `fieldData.label`: Solange
  /// die Detailseite offen ist, hält das Label nur den Control-Schlüssel
  /// (`field_0`, …, siehe FEATURE.md). Ohne den Umweg leitete die Namensregel
  /// aus „field_0" ab statt aus „Zahlungsfrist" — und der Anwalt sähe beim
  /// Umbenennen nie, dass sich die Ableitung mitändert.
  Widget _vorbelegung() {
    return ReactiveValueListenableBuilder<String>(
      formControlName: fieldData.label,
      builder: (context, control, _) => Padding(
        padding: const EdgeInsets.fromLTRB(46, 0, 8, 8),
        child: DatumsVorbelegungEditor(
          vorbelegung: fieldData.vorbelegung,
          feldname: control.value ?? '',
          onChanged: onVorbelegungChanged,
        ),
      ),
    );
  }

  /// Die eigentliche Feldzeile: Ziehgriff, Name, Typ, Datenquelle, Pflicht,
  /// Löschen. Als Liste herausgezogen, damit der Hinweis darunter passt, ohne
  /// die Zeile selbst zu verschachteln.
  List<Widget> _zeile(ThemeData theme) {
    return [
      ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(
              Icons.drag_indicator,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),

      Expanded(
        flex: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: GeneralTextField(
            formControlName: fieldData.label,
            inputDecoration: const InputDecoration(border: InputBorder.none),
            validationMessages: {
              ValidationMessage.required: (_) =>
                  'Der Feldname darf nicht leer sein.',
            },
          ),
        ),
      ),

      Expanded(
        flex: 2,
        child: SearchableDropdown<InputType>(
          value: fieldData.inputType,
          hintText: 'Typ suchen oder auswählen',
          entries: [
            for (final type in InputType.values)
              SearchableDropdownEntry(value: type, label: type.displayName),
          ],
          onChanged: onTypeChanged,
        ),
      ),

      Expanded(
        flex: 3,
        child: SearchableDropdown<FeldDatenquelle>(
          value: fieldData.datenquelle,
          hintText: 'Datenquelle suchen oder auswählen',
          entries: [
            for (final quelle in FeldDatenquelle.values)
              SearchableDropdownEntry(value: quelle, label: quelle.displayName),
          ],
          onChanged: onDatenquelleChanged,
        ),
      ),

      Expanded(flex: 2, child: _erforderlichSpalte(theme)),

      IconButton(
        icon: Icon(Icons.delete, color: theme.colorScheme.error),
        onPressed: onDelete,
      ),
    ];
  }

  /// Checkbox „Erforderlich" mit Beschriftung.
  ///
  /// Bei angehobener Schrift (Issue #57) und schmaler Spalte reicht der Platz
  /// oft nicht für Checkbox **und** „ERFORDERLICH" nebeneinander — die
  /// Beschriftung lief in den Löschen-Knopf rechts daneben. `Flexible` mit
  /// Ellipsis allein hätte nur ein abgeschnittenes „ERFORD…" gezeigt; unter
  /// [_mindestbreiteBeschriftung] entfällt die Beschriftung deshalb ganz und
  /// die Checkbox trägt ihren Zweck als Tooltip. Der `LayoutBuilder` misst
  /// genau die Breite, die diese Spalte vom `Expanded` bekommt — dieselbe
  /// Breite, die vorher überlief.
  Widget _erforderlichSpalte(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final genugPlatz = constraints.maxWidth >= _mindestbreiteBeschriftung;
        final checkbox = Checkbox(
          value: fieldData.required,
          activeColor: theme.colorScheme.primary,
          onChanged: onRequiredChanged,
        );
        final inhalt = Row(
          children: [
            checkbox,
            if (genugPlatz)
              Flexible(
                child: Text(
                  'ERFORDERLICH',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
          ],
        );
        return InkWell(
          onTap: () => onRequiredChanged.call(!fieldData.required),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: genugPlatz
              ? inhalt
              : Tooltip(message: 'Erforderlich', child: inhalt),
        );
      },
    );
  }

  /// Ab hier passen Checkbox und Beschriftung noch nebeneinander (empirisch an
  /// der größten Schriftstufe ermittelt — siehe `felder_karte_schmal_test.dart`).
  static const double _mindestbreiteBeschriftung = 150;
}
