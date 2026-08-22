import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorgang_abschliessen_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Abschluss des Vorgangs (Req. 3.2 / 3.7): markiert den Auftrag als erledigt
/// (Status „versendet"), zählt die laufende Auftragsnummer in den Einstellungen
/// hoch und nimmt den Vorgang damit ins Sachgebiete-Register auf. Greift den
/// gewählten Vorgang live aus dem [VorgangCubit] ab, damit der Status nach dem
/// Abschluss sofort umschlägt.
class VorgangAbschliessenSection extends StatelessWidget {
  const VorgangAbschliessenSection({super.key});

  Future<void> _abschliessen(BuildContext context, Vorgang vorgang) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => VorgangAbschliessenDialog(vorgang: vorgang),
    );
    if (bestaetigt != true || !context.mounted) return;
    // Statuswechsel und Auftragsnummer laufen atomar im Backend; bei false ist
    // nichts passiert und der Anwalt kann es erneut versuchen.
    final erfolgreich = await getIt<VorgangCubit>().abschliessen(vorgang);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erfolgreich
              ? 'Vorgang abgeschlossen und ins Register aufgenommen. Die '
                    'laufende Auftragsnummer wurde hochgezählt.'
              : 'Der Vorgang konnte nicht abgeschlossen werden — Status und '
                    'Auftragsnummer sind unverändert. Bitte erneut versuchen.',
        ),
        backgroundColor: erfolgreich
            ? null
            : Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = context.watch<WizardCubit>().state.selectedVorgang;

    if (selected == null) {
      return Column(
        children: [
          Text(
            'Vorgang abschließen',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Diesem Dokument ist kein Vorgang zugeordnet. Wählen Sie im ersten '
            'Schritt einen Vorgang, um ihn nach dem Versand abzuschließen '
            '(Auftragsnummer hochzählen, Registereintrag).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      );
    }

    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        final aktuell =
            getIt<VorgangCubit>().findeZuReferenz(selected.referenz) ??
            selected;
        final abgeschlossen = aktuell.status == VorgangStatus.versendet;

        return Column(
          children: [
            Text(
              'Vorgang abschließen',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${aktuell.referenz} · Status: ${aktuell.status.displayName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            if (abgeschlossen)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Abgeschlossen und ins Register aufgenommen.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _abschliessen(context, aktuell),
                icon: const Icon(Icons.task_alt),
                label: const Text('Vorgang abschließen'),
              ),
          ],
        );
      },
    );
  }
}
