import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_status_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Karte für eine der beiden Word-Dateien (ohne/mit Auflistung): Dateiauswahl,
/// Lesezustand und – beim Mit-Slot – die Warnung, falls
/// {{Schadensaufstellung}} fehlt.
///
/// **Die Chips sind seit Stufe 3a (#104) nicht mehr hier**, sondern im
/// zugeklappten `PlatzhalterAbschnitt` darunter. Die Karte beantwortet damit
/// genau eine Frage — *welche Datei hängt an diesem Slot?* —, und die linke
/// Spalte des zweispaltigen Editors beginnt nicht mehr mit vier Dutzend Chips
/// über allem, was eine Aufgabe ist. Was bleibt, ist die Auskunft, die zur
/// Datei selbst gehört: ihr Name, die beiden Knöpfe, „wird gelesen …" und ein
/// Lesefehler.
class TemplateFileSlotCard extends StatelessWidget {
  final TemplateFileSlot slot;
  final String? path;
  final String title;
  final String subtitle;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const TemplateFileSlotCard({
    super.key,
    required this.slot,
    required this.path,
    required this.title,
    required this.subtitle,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(subtitle, style: theme.textTheme.bodySmall),
            _dateizeile(theme),
            _knoepfe(),
            if (path != null)
              BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
                builder: (context, zustand) => _auskunft(theme, zustand),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateizeile(ThemeData theme) => Row(
    spacing: 10,
    children: [
      Icon(Icons.description, color: theme.colorScheme.primaryContainer),
      Expanded(
        child: Text(
          path ?? 'Keine Word-Datei verknüpft',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  /// Die beiden Handlungen. `Wrap` statt `Row`, und in einer **eigenen** Zeile
  /// unter dem Dateinamen: Die Karte steht seit Stufe 3a in einer 400 px
  /// schmalen Spalte, und „Andere Datei wählen" ist bei angehobener Schrift
  /// (Issue #57) allein schon breiter als der Platz neben einem Pfad.
  Widget _knoepfe() => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      if (path != null)
        IconButton(
          tooltip: 'Verknüpfung entfernen',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      CustomRectangularButton(
        icon: const Icon(Icons.file_open),
        label: Text(
          path == null ? 'Word-Datei verknüpfen' : 'Andere Datei wählen',
        ),
        onPressed: onPick,
      ),
    ],
  );

  /// Lesezustand und – nur beim Mit-Slot – die fehlende
  /// {{Schadensaufstellung}}.
  Widget _auskunft(ThemeData theme, TemplatePlaceholdersState zustand) {
    final ergebnis = zustand.forSlot(slot);
    final fehltAufstellung =
        slot == TemplateFileSlot.mitAuflistung &&
        ergebnis is SlotPlaceholdersLoaded &&
        !ergebnis.placeholders.any(
          (platzhalter) => platzhalter.toLowerCase() == 'schadensaufstellung',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        if (fehltAufstellung) _warnung(theme),
        PlatzhalterStatusZeile(zustand: ergebnis),
      ],
    );
  }

  Widget _warnung(ThemeData theme) => Row(
    spacing: 10,
    children: [
      const Icon(Icons.warning_amber, color: Colors.amber),
      Expanded(
        child: Text(
          'Die verknüpfte Word-Datei enthält keinen Platzhalter '
          '{{Schadensaufstellung}}. Ohne diesen Platzhalter '
          'schlägt die Dokumenterstellung mit Auflistung fehl.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    ],
  );
}
