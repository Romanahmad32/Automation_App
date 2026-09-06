import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_chips.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_status_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Zeigt die in der verknüpften Word-Datei eines [slot] erkannten
/// {{Platzhalter}} als Chips an. Ein Klick auf einen Chip übernimmt den
/// Platzhalter als neues Eingabefeld.
///
/// Seit Stufe 3a (#104) steht die Ansicht nicht mehr in der Dateikarte,
/// sondern im zugeklappten `PlatzhalterAbschnitt`; „wird gelesen …" und die
/// Fehlermeldung teilt sie sich über [PlatzhalterStatusZeile] mit der
/// Dateikarte, wo diese Auskunft weiterhin hingehört.
class TemplatePlaceholdersView extends StatelessWidget {
  final TemplateFileSlot slot;
  final void Function(String placeholder) onPlaceholderSelected;

  /// Die aktuell eingetragenen Feldnamen — für die Chip-Optik „übernommen"
  /// (#35 Teil 3). Gezählt wird hier nichts mehr; das sagt die
  /// `VorlagenStandKarte` über beide Dateien zusammen (#104).
  final Iterable<String?> vorhandeneNamen;

  const TemplatePlaceholdersView({
    super.key,
    required this.slot,
    required this.onPlaceholderSelected,
    this.vorhandeneNamen = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      builder: (context, state) {
        final ergebnis = state.forSlot(slot);
        switch (ergebnis) {
          case SlotPlaceholdersInitial():
          case SlotPlaceholdersLoading():
          case SlotPlaceholdersError():
            return PlatzhalterStatusZeile(zustand: ergebnis);
          case SlotPlaceholdersLoaded(placeholders: final placeholders):
            if (placeholders.isEmpty) {
              return Text(
                'In der Datei wurden keine {{Platzhalter}} gefunden.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  'Erkannte Platzhalter (anklicken, um sie als Eingabefeld zu übernehmen):',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PlatzhalterChips(
                  placeholders: placeholders,
                  vorhandeneNamen: vorhandeneNamen,
                  onPlaceholderSelected: onPlaceholderSelected,
                ),
              ],
            );
        }
      },
    );
  }
}
