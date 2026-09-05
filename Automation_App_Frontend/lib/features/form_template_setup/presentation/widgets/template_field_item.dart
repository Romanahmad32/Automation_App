import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/felder_filter.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_aufklapp_inhalt.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_bezeichnung_zelle.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/felder_spalten.dart';
import 'package:flutter/material.dart';

/// Eine Feldzeile im Vorlageneditor: Ziehgriff, Bezeichnung, Typ,
/// Datenquelle, Pflicht, Aufklapp-Chevron, Löschen — in den Spalten aus
/// [FelderSpalten], denselben, die der Tabellenkopf benutzt.
///
/// **Alles Seltene liegt im Aufklapper** ([FeldAufklappInhalt]): die
/// Datums-Vorbelegung und der Hinweis zu einem mehrdeutigen Namen. Zugeklappt
/// ist jede Zeile gleich hoch, und die Tabelle bleibt von oben nach unten
/// lesbar. Zu ist deshalb der Normalfall — mit einer Ausnahme: Ein
/// mehrdeutiger Name ist ein Befund, den der Anwalt sehen **muss**, also geht
/// diese Zeile offen auf. Klappt er sie zu, gewinnt seine Entscheidung.
class TemplateFieldItem extends StatefulWidget {
  /// Stelle in der **angezeigten** Liste — was der Ziehgriff der
  /// `ReorderableListView` melden muss. Bei aktivem Filter ist das nicht der
  /// Index im Feldbestand, deshalb ist Umsortieren dann aus
  /// ([umsortierenMoeglich]).
  final int index;

  final FieldData fieldData;

  /// Der **aufgelöste** Feldname (der Wert des Controls), nur zur Frage, ob
  /// die Zeile offen aufgeht. Was live mitlaufen muss — Warnung, Hinweis,
  /// Ableitung der Vorbelegung — hört selbst am Control; hier genügt der
  /// Stand beim Aufbau.
  final String? feldname;

  final ValueChanged<InputType?> onTypeChanged;
  final ValueChanged<FeldDatenquelle?> onDatenquelleChanged;
  final ValueChanged<bool?> onRequiredChanged;

  /// Die Datums-Vorbelegung des Felds wurde geändert (§5.3). Null nimmt die
  /// Einstellung zurück, sodass wieder die Namensregel greift.
  final ValueChanged<DatumsVorbelegung?> onVorbelegungChanged;

  final VoidCallback onDelete;

  /// Klick auf die Warnung „in keiner Datei" — führt zur Zuordnung (#36).
  final VoidCallback? onZuordnen;

  /// Ob der Ziehgriff zieht. Bei aktivem Filter nicht: Die Liste zeigt dann
  /// eine Auswahl, und ein Zug darin verschöbe das Feld an eine Stelle, die
  /// der Anwalt gar nicht sieht.
  final bool umsortierenMoeglich;

  const TemplateFieldItem({
    super.key,
    required this.index,
    required this.fieldData,
    required this.onTypeChanged,
    required this.onDatenquelleChanged,
    required this.onRequiredChanged,
    required this.onVorbelegungChanged,
    required this.onDelete,
    this.feldname,
    this.onZuordnen,
    this.umsortierenMoeglich = true,
  });

  @override
  State<TemplateFieldItem> createState() => _TemplateFieldItemState();
}

class _TemplateFieldItemState extends State<TemplateFieldItem> {
  /// Was der Anwalt am Chevron entschieden hat. Null heißt „noch nichts" —
  /// dann entscheidet der Inhalt, ob die Zeile offen aufgeht.
  bool? _gewaehlt;

  bool get _mussZeigen => FelderFilter.istZuPruefen(
    widget.feldname,
    datenquelleGesetzt: widget.fieldData.datenquelle.istGesetzt,
  );

  bool get _hatInhalt => FeldAufklappInhalt.hatInhalt(
    widget.fieldData,
    nameMehrdeutig: _mussZeigen,
  );

  bool get _offen => _hatInhalt && (_gewaehlt ?? _mussZeigen);

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
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mindest-, nicht Festhöhe: siehe FelderSpalten.zeilenHoehe.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: FelderSpalten.zeilenHoehe,
            ),
            child: FelderSpalten.zeile(_zellen(theme)),
          ),
          if (_offen)
            FeldAufklappInhalt(
              fieldData: widget.fieldData,
              onVorbelegungChanged: widget.onVorbelegungChanged,
            ),
        ],
      ),
    );
  }

  /// Je Spalte eine Zelle, in der Reihenfolge von [FelderSpalten.alle].
  List<Widget> _zellen(ThemeData theme) => [
    _griff(theme),
    FeldBezeichnungZelle(
      formControlName: widget.fieldData.label,
      onZuordnen: widget.onZuordnen,
    ),
    SearchableDropdown<InputType>(
      value: widget.fieldData.inputType,
      hintText: 'Typ wählen',
      entries: [
        for (final type in InputType.values)
          SearchableDropdownEntry(value: type, label: type.displayName),
      ],
      onChanged: widget.onTypeChanged,
    ),
    SearchableDropdown<FeldDatenquelle>(
      value: widget.fieldData.datenquelle,
      hintText: 'Quelle wählen',
      entries: [
        for (final quelle in FeldDatenquelle.values)
          SearchableDropdownEntry(value: quelle, label: quelle.displayName),
      ],
      onChanged: widget.onDatenquelleChanged,
    ),
    _pflicht(theme),
    _chevron(),
    IconButton(
      tooltip: 'Feld löschen',
      icon: Icon(Icons.delete, color: theme.colorScheme.error),
      onPressed: widget.onDelete,
    ),
  ];

  Widget _griff(ThemeData theme) {
    final symbol = Icon(
      Icons.drag_indicator,
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (!widget.umsortierenMoeglich) {
      return Tooltip(
        message: 'Zum Umsortieren den Filter auf „Alle" stellen',
        child: Opacity(opacity: 0.38, child: symbol),
      );
    }
    return ReorderableDragStartListener(
      index: widget.index,
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: symbol),
    );
  }

  /// Nur die Checkbox: Was sie bedeutet, steht als Aufschrift im
  /// Tabellenkopf. Vorher trug jede Zeile ihr eigenes „ERFORDERLICH" und
  /// musste es bei angehobener Schrift (Issue #57) messen und wegblenden,
  /// damit es nicht in den Löschen-Knopf lief — eine Spaltenüberschrift, die
  /// achtzehnmal wiederholt wird, ist keine.
  Widget _pflicht(ThemeData theme) {
    return Tooltip(
      message: 'Erforderlich — ohne diese Angabe wird nicht erzeugt',
      child: Checkbox(
        value: widget.fieldData.required,
        activeColor: theme.colorScheme.primary,
        onChanged: widget.onRequiredChanged,
      ),
    );
  }

  Widget _chevron() {
    return IconButton(
      tooltip: _hatInhalt
          ? (_offen ? 'Einzelheiten zuklappen' : 'Einzelheiten aufklappen')
          : 'Zu diesem Feld gibt es nichts weiter einzustellen',
      icon: Icon(_offen ? Icons.expand_less : Icons.expand_more),
      onPressed: _hatInhalt ? () => setState(() => _gewaehlt = !_offen) : null,
    );
  }
}
