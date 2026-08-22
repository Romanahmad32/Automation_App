import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:flutter/material.dart';

/// Auswahl des Mandanten im Speicherschritt: zeigt entweder den gewählten
/// Mandanten als Karte (mit „Ändern") oder ein Dropdown bestehender Mandanten
/// plus den Button zum Neuanlegen. Hält selbst keinen State — Auswahl und
/// Anlegen meldet es über Callbacks zurück.
class MandantAuswahl extends StatelessWidget {
  final Mandant? mandant;
  final List<Mandant> mandanten;
  final void Function(Mandant) onWaehleMandant;
  final VoidCallback onNeuerMandant;
  final VoidCallback onAendern;

  const MandantAuswahl({
    super.key,
    required this.mandant,
    required this.mandanten,
    required this.onWaehleMandant,
    required this.onNeuerMandant,
    required this.onAendern,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gewaehlt = mandant;
    if (gewaehlt != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.person, color: theme.colorScheme.primary),
          title: Text(
            gewaehlt.anzeigename.isEmpty
                ? '(ohne Namen)'
                : gewaehlt.anzeigename,
          ),
          subtitle: const Text('Mandant'),
          trailing: TextButton(
            onPressed: onAendern,
            child: const Text('Ändern'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mandanten.isNotEmpty)
          SearchableDropdown<int>(
            value: null,
            labelText: 'Bestehenden Mandanten wählen',
            hintText: 'Mandant suchen oder auswählen',
            leadingIcon: const Icon(Icons.person_search),
            entries: [
              for (final m in mandanten)
                SearchableDropdownEntry(
                  value: m.id,
                  label: m.anzeigename.isEmpty ? '(ohne Namen)' : m.anzeigename,
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              onWaehleMandant(mandanten.firstWhere((m) => m.id == id));
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onNeuerMandant,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Neuen Mandanten anlegen'),
        ),
        const SizedBox(height: 4),
        Text(
          'Der neue Mandant wird mit den Daten aus dem Formular vorbelegt.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
