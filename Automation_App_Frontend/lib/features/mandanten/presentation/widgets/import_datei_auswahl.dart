import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_anleitung.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Einstieg in den Import: erklären, wie die Datei entsteht, und sie
/// auswählen lassen.
///
/// Hier wird nur **gelesen**. Die Arbeit gibt „Arbeitspaket holen" im
/// Zuordnungsstapel heraus, und den Auftrag dazu gleich mit. Diese Seite bot
/// ihn einmal ein zweites Mal an — in einer eigenen Fassung ohne Paket, mit
/// eigenem Knopf — und ließ damit offen, welcher der beiden gilt. Geblieben
/// ist der Aufbau der Antwortdatei zum Nachschlagen: eine Frage an das Format,
/// keine zweite Auftragsvergabe.
class ImportDateiAuswahl extends StatelessWidget {
  const ImportDateiAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(
          'Zuordnung aus einer Datei übernehmen',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Für rund 4000 Akten-Ordner ist die Zuordnung von Hand nicht zu '
          'schaffen. Stattdessen wird sie auf dem Kanzleirechner aus den '
          'Ordnernamen und den Schreiben darin zusammengetragen und als '
          'JSON-Datei hier eingelesen. Welche Ordner dabei zu bearbeiten sind '
          'und was damit zu tun ist, gibt „Arbeitspaket holen" im '
          'Zuordnungsstapel heraus.\n\n'
          'Eingelesen heißt zunächst nur: geprüft und gezeigt. Geschrieben '
          'wird erst, wenn Sie die Vorschau gesehen und bestätigt haben.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _waehlen(context),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('JSON-Datei wählen'),
          ),
        ),
        const SizedBox(height: 24),
        ExpansionTile(
          title: const Text('Aufbau der Antwortdatei ansehen'),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            SelectableText(
              ImportAnleitung.dateiaufbau.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _waehlen(BuildContext context) async {
    final cubit = context.read<MandantenImportCubit>();
    final auswahl = await FilePicker.pickFiles(
      dialogTitle: 'Importdatei wählen',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final pfad = auswahl?.files.single.path;
    if (pfad == null) return;
    await cubit.dateiWaehlen(pfad);
  }
}
