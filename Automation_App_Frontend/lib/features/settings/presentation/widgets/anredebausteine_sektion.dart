import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/hinzufuegen_button.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_state.dart';
import 'package:automation_app/features/settings/presentation/widgets/anredebaustein_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Verwaltung der Anredeanfänge (§4.7, §7.1) — im Reiter „E-Mail", über den
/// Zusatzgrüßen, weil die Anrede vor dem Gruß steht.
///
/// Gepflegt wird nur der **Anfang** in seinen drei Beugungsformen; „Herr"/„Frau"
/// und den Nachnamen setzt der Versand dazu. Der erste der Liste gilt beim
/// Verfassen ohne Klick.
class AnredebausteineSektion extends StatelessWidget {
  const AnredebausteineSektion({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AnredebausteineCubit>()..ladenWennNoetig(),
      child: const AnredebausteineSektionInhalt(),
    );
  }
}

/// Der Abschnitt selbst, unter dem bereitgestellten [AnredebausteineCubit].
class AnredebausteineSektionInhalt extends StatelessWidget {
  const AnredebausteineSektionInhalt({super.key});

  Future<void> _bearbeite(BuildContext context, Anredebaustein baustein) {
    final cubit = context.read<AnredebausteineCubit>();
    return showDialog<bool>(
      context: context,
      builder: (_) => AnredebausteinDialog(
        baustein: baustein,
        onSpeichern: cubit.speichere,
      ),
    );
  }

  /// Erst fragen, dann entfernen (§7.1, ergänzt am 03.09.2026). Der Anfang
  /// kommt nicht wieder — und wer den ersten der Liste erwischt, ändert die
  /// Anrede **jeder** künftigen Mail: Ohne Klick gilt beim Verfassen, was
  /// vorn steht (`AnredebausteineState.vorgabe`).
  Future<void> _entferne(BuildContext context, Anredebaustein baustein) async {
    final cubit = context.read<AnredebausteineCubit>();
    final sicher = await bestaetigen(
      context,
      icon: Icons.warning_rounded,
      titel: 'Anrede entfernen?',
      text:
          '„${baustein.bezeichnung}" wird aus dem Bestand gelöscht und steht '
          'beim Verfassen nicht mehr zur Auswahl. Bereits versendete Mails '
          'bleiben davon unberührt.',
      bestaetigung: 'Entfernen',
      destruktiv: true,
    );
    if (sicher) await cubit.loesche(baustein.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnredebausteineCubit, AnredebausteineState>(
      builder: (context, stand) {
        return FormSection(
          icon: Icons.record_voice_over_outlined,
          title: 'Anreden',
          subtitle:
              'Nur der Anfang — „Herr"/„Frau" und den Nachnamen setzt der '
              'Versand dazu, die Beugung folgt dem Mandanten. Der erste gilt '
              'beim Verfassen ohne Klick.',
          trailing: stand.laedt
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          children: [
            if (stand.fehler != null)
              Text(
                stand.fehler!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (stand.geladen && stand.bausteine.isEmpty)
              const Text(
                'Keine Anrede hinterlegt. Dann gilt weiter „Sehr geehrter '
                'Herr …" bzw. „Sehr geehrte Damen und Herren".',
              ),
            if (stand.bausteine.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final baustein in stand.bausteine)
                    InputChip(
                      label: Text(baustein.bezeichnung),
                      onPressed: () => _bearbeite(context, baustein),
                      onDeleted: () => _entferne(context, baustein),
                      deleteButtonTooltipMessage: 'Anrede entfernen',
                    ),
                ],
              ),
            HinzufuegenButton(
              beschriftung: 'Anrede hinzufügen',
              onHinzufuegen: () => _bearbeite(context, const Anredebaustein()),
            ),
          ],
        );
      },
    );
  }
}
