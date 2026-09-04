import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_anleitung.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Einstieg in den Import: erklären, wie die Datei entsteht, und sie
/// auswählen lassen.
///
/// Der zweite Knopf ist kein Beiwerk. Die Datei entsteht außerhalb dieser App,
/// und wer sie erzeugt, braucht das Format wortgleich — deshalb liegt der
/// fertige Auftrag hier zum Kopieren, statt in einer Anleitung, die man erst
/// suchen und dann abschreiben müsste.
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
          'JSON-Datei hier eingelesen.\n\n'
          'Eingelesen heißt zunächst nur: geprüft und gezeigt. Geschrieben '
          'wird erst, wenn Sie die Vorschau gesehen und bestätigt haben.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _waehlen(context),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('JSON-Datei wählen'),
            ),
            OutlinedButton.icon(
              onPressed: () => _anleitungKopieren(context),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Auftrag für den Erzeuger kopieren'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ExpansionTile(
          title: const Text('Format und Auftrag ansehen'),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            SelectableText(
              ImportAnleitung.text.trim(),
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

  Future<void> _anleitungKopieren(BuildContext context) async {
    final bote = Rueckmeldung.von(context);
    await Clipboard.setData(ClipboardData(text: ImportAnleitung.text.trim()));
    bote.erfolg(
      'Auftrag kopiert — auf dem Kanzleirechner einfügen, den Stammordner '
      'eintragen und die Datei erzeugen lassen.',
    );
  }
}
