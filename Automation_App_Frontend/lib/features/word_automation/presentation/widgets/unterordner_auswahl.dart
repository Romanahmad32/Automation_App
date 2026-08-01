import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_constants.dart';
import 'package:flutter/material.dart';

/// Auswahl des Unterordners (Fall) innerhalb der Akte: Dropdown über vorhandene
/// Fälle (plus „Neuen Unterordner anlegen …") und/oder Felder für Stichwort,
/// Ursachendatum und Kennzeichen, aus denen sich der Ordnername zusammensetzt.
/// Zustandslos — meldet Änderungen über [onDropdownChanged] und [onTextChanged].
class UnterordnerAuswahl extends StatelessWidget {
  final bool neuerFall;
  final String? gewaehlterFall;
  final List<String> faelle;
  final TextEditingController stichwortController;
  final TextEditingController datumController;
  final TextEditingController kennzeichenController;
  final String vorschau;
  final void Function(String? value) onDropdownChanged;
  final VoidCallback onTextChanged;

  const UnterordnerAuswahl({
    super.key,
    required this.neuerFall,
    required this.gewaehlterFall,
    required this.faelle,
    required this.stichwortController,
    required this.datumController,
    required this.kennzeichenController,
    required this.vorschau,
    required this.onDropdownChanged,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    if (faelle.isNotEmpty) {
      children.add(
        SearchableDropdown<String>(
          value: neuerFall ? neuSentinel : gewaehlterFall,
          labelText: 'Unterordner (Fall)',
          hintText: 'Fall suchen oder auswählen',
          leadingIcon: const Icon(Icons.topic_outlined),
          entries: [
            for (final f in faelle) SearchableDropdownEntry(value: f, label: f),
            const SearchableDropdownEntry(
              value: neuSentinel,
              label: '＋ Neuen Unterordner anlegen …',
            ),
          ],
          onChanged: onDropdownChanged,
        ),
      );
    }

    if (neuerFall || faelle.isEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: stichwortController,
                onChanged: (_) => onTextChanged(),
                decoration: const InputDecoration(
                  labelText: 'Stichwort',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: datumController,
                onChanged: (_) => onTextChanged(),
                decoration: const InputDecoration(
                  labelText: 'Ursachendatum',
                  hintText: 'TT.MM.JJJJ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: kennzeichenController,
                onChanged: (_) => onTextChanged(),
                decoration: const InputDecoration(
                  labelText: 'Kennzeichen (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
      children.add(const SizedBox(height: 8));
      children.add(
        Text(
          'Ordnername: $vorschau',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
