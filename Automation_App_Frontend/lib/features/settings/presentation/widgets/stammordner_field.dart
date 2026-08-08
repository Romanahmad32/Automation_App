import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Auswahl des Akten-Stammordners: schreibgeschütztes Pfadfeld plus ein
/// Button, der den nativen Ordner-Auswahldialog öffnet. Der Pfad wird nicht
/// frei getippt, damit kein ungültiger/nicht existierender Ordner gespeichert
/// wird.
class StammordnerField extends StatelessWidget {
  const StammordnerField({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: 'aktenStammordner',
      builder: (context, control, _) {
        final pfad = (control.value ?? '').trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: pfad),
                    decoration: InputDecoration(
                      labelText: 'Stammordner des Aktensystems',
                      hintText: 'Noch kein Ordner gewählt',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.folder_outlined),
                      suffixIcon: pfad.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Stammordner entfernen',
                              onPressed: () => control.value = '',
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await FilePicker.getDirectoryPath(
                      dialogTitle: 'Stammordner des Aktensystems wählen',
                    );
                    if (selected != null) control.value = selected;
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ordner wählen'),
                ),
              ],
            ),
            if (pfad.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Ohne Stammordner kann die App fertige Dokumente nicht '
                'automatisch in die Akte ablegen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
