import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart';
import 'package:automation_app/features/word_automation/domain/usecases/arbeitsordner_aufraeumen.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/mail_versenden_button.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorgang_abschliessen_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Versand und Abschluss des Vorgangs (§4.7, §4.8) — die beiden letzten
/// Schritte, bewusst getrennt: Die Mail kann mehrfach hinausgehen (Mandant
/// nachträglich, Korrekturschreiben), abgeschlossen wird genau einmal. Der
/// Abschluss markiert den Auftrag als erledigt, zählt die laufende
/// Auftragsnummer hoch und nimmt den Vorgang ins Sachgebiete-Register auf.
///
/// Zugleich der letzte Halt für den Arbeitsordner: Ist der Auftrag erledigt,
/// kann darin nichts mehr gebraucht werden. Die Ablage räumt ihn nur auf, wenn
/// die Word-Fassung in der Akte landet (§4.6) — bei „nur PDF" bliebe er sonst
/// bis zur Altersgrenze des Dienstes stehen.
class VorgangAbschliessenSection extends StatefulWidget {
  const VorgangAbschliessenSection({super.key});

  @override
  State<VorgangAbschliessenSection> createState() =>
      _VorgangAbschliessenSectionState();
}

class _VorgangAbschliessenSectionState
    extends State<VorgangAbschliessenSection> {
  /// Der Versand dieser Sitzung — er begründet im Abschlussdialog das
  /// vorbelegte Häkchen. Bewusst nicht am Vorgang persistiert: §4.7 verlangt
  /// keinen Versandnachweis in der App, dafür genügt der Ordner „Gesendet".
  EmailVersandErgebnis? _versand;

  void _versandUebernehmen(EmailVersandErgebnis ergebnis) {
    if (!mounted) return;
    setState(() => _versand = ergebnis);
  }

  Future<void> _abschliessen(BuildContext context, Vorgang vorgang) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => VorgangAbschliessenDialog(
        vorgang: vorgang,
        mandant: context.read<WizardCubit>().state.selectedMandant,
        bereitsVersendet: _versand,
        onVersendet: _versandUebernehmen,
      ),
    );
    if (bestaetigt != true || !context.mounted) return;
    // Statuswechsel und Auftragsnummer laufen atomar im Backend; bei false ist
    // nichts passiert und der Anwalt kann es erneut versuchen.
    final erfolgreich = await getIt<VorgangCubit>().abschliessen(vorgang);
    if (erfolgreich) await _arbeitsordnerRaeumen(vorgang);
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

  /// Löscht die Arbeitskopien des abgeschlossenen Vorgangs. Bewusst
  /// stillschweigend: Der Abschluss ist gelungen, und ob nebenbei eine
  /// Arbeitsdatei liegen blieb (weil sie noch in Word offen ist), geht den
  /// Anwalt nichts an — die Altersgrenze des Dienstes holt sie später.
  Future<void> _arbeitsordnerRaeumen(Vorgang vorgang) async {
    await getIt<
      UseCase<ArbeitsordnerAufraeumung, ArbeitsordnerAufraeumenParams>
    >()(ArbeitsordnerAufraeumenParams(vorgang.referenz));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wizard = context.watch<WizardCubit>().state;
    final selected = wizard.selectedVorgang;

    if (selected == null) {
      return Column(
        children: [
          Text(
            'E-Mail und Abschluss',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Diesem Dokument ist kein Vorgang zugeordnet. Wählen Sie im ersten '
            'Schritt einen Vorgang, um das Schreiben zu versenden und den '
            'Vorgang danach abzuschließen (Auftragsnummer hochzählen, '
            'Registereintrag).',
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
              'E-Mail und Abschluss',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${aktuell.zeichen} · Status: ${aktuell.status.displayName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            MailVersendenButton(
              vorgang: aktuell,
              mandant: wizard.selectedMandant,
              bereitsVersendet: _versand,
              onVersendet: _versandUebernehmen,
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
