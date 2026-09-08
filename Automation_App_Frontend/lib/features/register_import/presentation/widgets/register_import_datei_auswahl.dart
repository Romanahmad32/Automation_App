import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_anleitung_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Einstieg in die Übernahme: erklären, wie die Datei entsteht, und sie
/// auswählen lassen (§6.2).
///
/// Der zweite Knopf ist kein Beiwerk. Die Datei entsteht außerhalb dieser App,
/// und wer sie erzeugt, braucht das Format wortgleich — deshalb liegt der
/// fertige Auftrag hier, samt der Jahrgangs-Auswahl, statt in einer Anleitung,
/// die man erst suchen und dann abschreiben müsste.
class RegisterImportDateiAuswahl extends StatelessWidget {
  /// Der Jahrgang, den die Anleitung vorschlägt — vom Stand auf Tab 6 der
  /// kleinste fehlende.
  final int? vorgeschlagenerJahrgang;

  const RegisterImportDateiAuswahl({super.key, this.vorgeschlagenerJahrgang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(
          'Registerhistorie in Jahrgängen übernehmen',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Das Register der Kanzlei liegt als Word-Dokument mit rund neunzig '
          'Seiten vor. Es wird auf dem Kanzleirechner Jahrgang für Jahrgang in '
          'eine JSON-Datei umgesetzt und hier eingelesen.\n\n'
          'Eingelesen heißt zunächst nur: geprüft und gezeigt. Die App zählt '
          'die laufenden Nummern durch, meldet Lücken, Doppelte und '
          'Widersprüche — geschrieben wird erst, wenn Sie den Jahrgang '
          'freigeben.',
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
              onPressed: () => _anleitung(context),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Auftrag für den Erzeuger'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _waehlen(BuildContext context) async {
    final cubit = context.read<RegisterImportCubit>();
    final auswahl = await FilePicker.pickFiles(
      dialogTitle: 'Registerdatei wählen',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final pfad = auswahl?.files.single.path;
    if (pfad == null) return;
    await cubit.dateiWaehlen(pfad);
  }

  Future<void> _anleitung(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => RegisterImportAnleitungDialog(
      vorgeschlagenerJahrgang: vorgeschlagenerJahrgang,
    ),
  );
}
