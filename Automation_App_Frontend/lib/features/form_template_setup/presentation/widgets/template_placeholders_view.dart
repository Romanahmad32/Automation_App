import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Zeigt die in der verknüpften Word-Datei eines [slot] erkannten
/// {{Platzhalter}} als Chips an. Ein Klick auf einen Chip übernimmt den
/// Platzhalter als neues Eingabefeld.
class TemplatePlaceholdersView extends StatelessWidget {
  final TemplateFileSlot slot;
  final void Function(String placeholder) onPlaceholderSelected;

  const TemplatePlaceholdersView({
    super.key,
    required this.slot,
    required this.onPlaceholderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      builder: (context, state) {
        switch (state.forSlot(slot)) {
          case SlotPlaceholdersInitial():
            return const SizedBox.shrink();
          case SlotPlaceholdersLoading():
            return const Row(
              spacing: 10,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                Text('Platzhalter werden gelesen …'),
              ],
            );
          case SlotPlaceholdersError(message: final message):
            return Text(
              message,
              style: TextStyle(color: theme.colorScheme.error),
            );
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final placeholder in placeholders)
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text('{{$placeholder}}'),
                        tooltip: 'Als Eingabefeld übernehmen',
                        onPressed: () => onPlaceholderSelected(placeholder),
                      ),
                  ],
                ),
              ],
            );
        }
      },
    );
  }
}
