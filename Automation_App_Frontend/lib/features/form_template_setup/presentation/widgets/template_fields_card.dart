import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/felder_filter.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/felder_karte_kopf.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_field_item.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_table_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Karte mit den Eingabefeldern der Vorlage: Kopfzeile mit Filter und
/// ⋯-Menü, Tabellenkopf, sortierbare Liste (Drag & Drop) und je Feld
/// Typ/Datenquelle/Pflicht/Löschen.
///
/// Der Filter lebt **hier** und nicht auf der Detailseite: Er ist eine Frage
/// der Ansicht, keine der Vorlage — die Seite müsste ihn sonst durchreichen,
/// speichern und beim Verlassen vergleichen, obwohl sich durch ihn nichts
/// ändert.
///
/// Die Karte kann **zwei Anordnungen** ([eigenerScrollbereich]) statt zwei
/// Karten zu sein: Zwei Fassungen desselben Kartenkopfs, desselben Filters und
/// derselben Zeile liefen bei der nächsten Änderung auseinander — dieselbe
/// Falle, aus der `FelderSpalten` entstand.
class TemplateFieldsCard extends StatefulWidget {
  final List<FieldData> fields;
  final FormGroup formGroup;
  final VoidCallback onAddField;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index, InputType? newValue) onTypeChanged;
  final void Function(int index, FeldDatenquelle? newValue)
  onDatenquelleChanged;
  final void Function(int index, bool? value) onRequiredChanged;

  /// Datums-Vorbelegung einer Zeile geändert (§5.3). Ohne Rückmeldung bleibt
  /// der Einsteller wirkungslos — die Karte kommt in Tests auch ohne vor.
  final void Function(int index, DatumsVorbelegung? neuerWert)?
  onVorbelegungChanged;

  final void Function(int index) onDelete;

  /// Klick auf die Warnung „in keiner Datei" einer Zeile (#36).
  final void Function(int index)? onZuordnen;

  /// Die Rechnung „Was fehlt dieser Vorlage noch?" (#104).
  final VorlagenStand stand;

  /// Löst einen Control-Schlüssel (`field_0`, …) zum echten Feldnamen auf.
  final String? Function(String controlKey) feldname;

  /// `true` in der zweispaltigen Anordnung: Die Karte füllt die Höhe, die ihr
  /// `VorlagenEditorLayout` gibt, Kartenkopf und Tabellenkopf bleiben beim
  /// Scrollen stehen, und nur die Zeilen laufen — echt virtualisiert, also
  /// ohne `shrinkWrap`. Bei achtzehn Feldern baut die Liste dann noch die
  /// sichtbaren statt aller.
  ///
  /// `false` (Vorgabe) im gestapelten Fall: Die Karte wächst mit ihrem Inhalt
  /// und scrollt mit der Seite. Ein Scrollbereich in einem Scrollbereich hätte
  /// dort keine eigene Höhe.
  final bool eigenerScrollbereich;

  const TemplateFieldsCard({
    super.key,
    required this.fields,
    required this.formGroup,
    required this.onAddField,
    required this.onReorder,
    required this.onTypeChanged,
    required this.onDatenquelleChanged,
    required this.onRequiredChanged,
    required this.onDelete,
    this.onVorbelegungChanged,
    this.onZuordnen,
    required this.stand,
    required this.feldname,
    this.eigenerScrollbereich = false,
  });

  @override
  State<TemplateFieldsCard> createState() => _TemplateFieldsCardState();
}

class _TemplateFieldsCardState extends State<TemplateFieldsCard> {
  /// Was der Anwalt gewählt hat; null heißt „noch nichts" — dann entscheidet
  /// [FelderFilter.start] anhand des Stands, und zwar bei jedem Aufbau neu.
  /// Ein einmal in `initState` festgehaltener Wert stünde auf dem Stand von
  /// vor dem Laden der Platzhalter und bliebe deshalb immer „Alle".
  FelderFilter? _gewaehlt;

  FelderFilter get _filter => _gewaehlt ?? FelderFilter.start(widget.stand);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sichtbare = _filter.sichtbareIndizes(
      fields: widget.fields,
      feldname: widget.feldname,
      stand: widget.stand,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FelderKarteKopf(
              anzahlFelder: widget.fields.length,
              filter: _filter,
              onFilter: (wert) => setState(() => _gewaehlt = wert),
              zahl: (wert) => wert.anzahl(
                fields: widget.fields,
                feldname: widget.feldname,
                stand: widget.stand,
              ),
              onNeuesFeld: widget.onAddField,
            ),
            const SizedBox(height: 24),

            if (widget.fields.isEmpty)
              const Center(child: Text('Keine Felder hinzugefügt'))
            else ...[
              // Der Tabellenkopf steht **außerhalb** der Liste. Mit eigenem
              // Scrollbereich bleibt er dadurch von selbst stehen — er ist gar
              // nicht Teil dessen, was scrollt.
              const TemplateFieldsTableHeader(),
              if (sichtbare.isEmpty)
                _leereAuswahl(theme)
              else if (widget.eigenerScrollbereich)
                Expanded(child: _liste(sichtbare))
              else
                _liste(sichtbare),
            ],

            _platzhalterZeile(theme),
          ],
        ),
      ),
    );
  }

  Widget _liste(List<int> sichtbare) {
    return ReorderableListView.builder(
      // Gestapelt trägt die Seite den Scrollbereich, die Liste baut alle
      // Zeilen und rührt sich nicht. Zweispaltig ist es umgekehrt: eigene
      // Physik in begrenzter Höhe, und `shrinkWrap` **aus** — sonst baute die
      // Liste trotz Scrollbereich jede Zeile, und die Virtualisierung wäre nur
      // dem Namen nach eine.
      shrinkWrap: !widget.eigenerScrollbereich,
      physics: widget.eigenerScrollbereich
          ? null
          : const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: widget.onReorder,
      // Das gezogene Element wird in ein Overlay außerhalb des ReactiveForm
      // UND der Bloc-Provider der Seite gehoben — hier beides neu umschließen
      // (die Warnung in der Zeile braucht den TemplatePlaceholdersBloc).
      proxyDecorator: (child, index, animation) {
        return BlocProvider.value(
          value: context.read<TemplatePlaceholdersBloc>(),
          child: ReactiveForm(
            formGroup: widget.formGroup,
            child: Material(color: Colors.transparent, child: child),
          ),
        );
      },
      itemCount: sichtbare.length,
      itemBuilder: (context, position) {
        final index = sichtbare[position];
        final feld = widget.fields[index];
        return TemplateFieldItem(
          // Der Control-Schlüssel, nicht der Name: Er bleibt beim Umbenennen
          // derselbe, und nur deshalb behält die Zeile beim Tippen ihren
          // Zustand (siehe FALLSTRICKE.md).
          key: ValueKey(feld.label),
          // Die Stelle in der **angezeigten** Liste — was der Ziehgriff
          // melden muss.
          index: position,
          fieldData: feld,
          feldname: widget.feldname(feld.label),
          umsortierenMoeglich: _filter == FelderFilter.alle,
          onTypeChanged: (neu) => widget.onTypeChanged(index, neu),
          onDatenquelleChanged: (neu) =>
              widget.onDatenquelleChanged(index, neu),
          onRequiredChanged: (wert) => widget.onRequiredChanged(index, wert),
          onVorbelegungChanged: (wert) =>
              widget.onVorbelegungChanged?.call(index, wert),
          onDelete: () => widget.onDelete(index),
          onZuordnen: widget.onZuordnen == null
              ? null
              : () => widget.onZuordnen!(index),
        );
      },
    );
  }

  Widget _leereAuswahl(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        _filter == FelderFilter.nurOffene
            ? 'Kein Feld ist offen.'
            : 'Kein Feld ist zu prüfen.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Die andere Hälfte von „offen": Platzhalter, zu denen kein Feld gehört.
  ///
  /// Sie haben keine Zeile, in der sie stehen könnten — trotzdem zählen sie
  /// im Filter mit ([VorlagenStand.anzahlOffen]). Ohne diesen Satz stünde die
  /// Karte da mit „Nur offene (3)" und einer leeren Liste, und niemand wüsste,
  /// wo die drei sind.
  Widget _platzhalterZeile(ThemeData theme) {
    final offen = widget.stand.platzhalterOhneFeld;
    if (_filter != FelderFilter.nurOffene || offen.isEmpty) {
      return const SizedBox.shrink();
    }
    final anzahl = offen.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        spacing: 8,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          Expanded(
            child: Text(
              '$anzahl Platzhalter ohne Feld — siehe Dateien/Platzhalter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
