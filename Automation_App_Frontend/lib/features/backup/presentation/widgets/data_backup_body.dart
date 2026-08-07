import 'package:automation_app/features/backup/presentation/cubit/backup_cubit.dart';
import 'package:automation_app/features/backup/presentation/cubit/backup_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Inhalt des Tabs „Datensicherung": exportiert die gesamte Datenbank in eine
/// Datei und spielt eine solche Sicherung wieder ein. Der Import überschreibt
/// alle Daten und wird erst nach Rückfrage ausgeführt (das Backend legt zuvor
/// automatisch eine Sicherung des bisherigen Standes an).
class DataBackupBody extends StatefulWidget {
  const DataBackupBody({super.key});

  @override
  State<DataBackupBody> createState() => _DataBackupBodyState();
}

class _DataBackupBodyState extends State<DataBackupBody> {
  String _datumsstempel() {
    final now = DateTime.now();
    String zwei(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${zwei(now.month)}${zwei(now.day)}'
        '-${zwei(now.hour)}${zwei(now.minute)}${zwei(now.second)}';
  }

  Future<void> _sichern() async {
    final zielPfad = await FilePicker.platform.saveFile(
      dialogTitle: 'Datensicherung speichern',
      // ZIP, weil die Sicherung seit der Verlagerung der Vorlagen nach %APPDATA%
      // nicht mehr nur die Datenbank enthält, sondern auch die .docx-Vorlagen,
      // auf die sie verweist.
      fileName: 'automation-backup-${_datumsstempel()}.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (zielPfad == null || !mounted) return;
    await context.read<BackupCubit>().exportiere(zielPfad);
  }

  Future<void> _einspielen() async {
    final auswahl = await FilePicker.platform.pickFiles(
      dialogTitle: 'Datensicherung einspielen',
      type: FileType.custom,
      // db/bak bleiben zugelassen: ältere Sicherungen aus der Zeit vor dem
      // Vorlagenordner spielt der Dienst weiterhin ein.
      allowedExtensions: ['zip', 'db', 'bak'],
    );
    final pfad = auswahl?.files.single.path;
    if (pfad == null || !mounted) return;

    final bestaetigt = await _bestaetigeImport();
    if (bestaetigt != true || !mounted) return;
    await context.read<BackupCubit>().importiere(pfad);
  }

  Future<bool?> _bestaetigeImport() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sicherung einspielen?'),
        content: const Text(
          'Dabei werden alle aktuellen Daten durch die Sicherung ersetzt. '
          'Der bisherige Stand wird zuvor automatisch als Sicherungskopie '
          'abgelegt. Nach dem Einspielen die App bitte neu starten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Einspielen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<BackupCubit, BackupState>(
      listener: (context, state) {
        if (state is BackupErfolg) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.meldung)));
        } else if (state is BackupFehler) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.meldung),
                backgroundColor: theme.colorScheme.error,
              ),
            );
        }
      },
      builder: (context, state) {
        final busy = state is BackupBusy;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Datensicherung', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Sichert alle Daten (Mandanten, Vorgänge, Einstellungen, '
                    'erfasste Antworten) in eine einzelne Datei und spielt sie '
                    'bei Bedarf wieder ein — etwa für ein Backup oder den Umzug '
                    'auf einen neuen Rechner.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : _sichern,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Daten sichern …'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _einspielen,
                    icon: const Icon(Icons.restore),
                    label: const Text('Sicherung einspielen …'),
                  ),
                  const SizedBox(height: 16),
                  DataBackupStatus(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Statuszeile unter den Knöpfen: Spinner während einer Aktion, sonst die letzte
/// Erfolgs- oder Fehlermeldung.
class DataBackupStatus extends StatelessWidget {
  final BackupState state;

  const DataBackupStatus({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (state) {
      case BackupBusy(:final meldung):
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(meldung, style: theme.textTheme.bodySmall)),
          ],
        );
      case BackupErfolg(:final meldung):
        return Text(
          meldung,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        );
      case BackupFehler(:final meldung):
        return Text(
          meldung,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        );
      case BackupIdle():
        return const SizedBox.shrink();
    }
  }
}
