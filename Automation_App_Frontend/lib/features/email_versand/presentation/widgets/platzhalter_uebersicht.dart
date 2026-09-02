import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagentext_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Was die Platzhalter der gewählten Vorlage ergeben haben (§4.7) — und was
/// leer blieb.
///
/// **Zugeklappt und beiläufig.** Sie beantwortet eine Frage, die sich nur
/// manchmal stellt: Ein fertig gefüllter Text verrät nicht mehr, aus welcher
/// Vorlage er stammt und welcher Platzhalter wofür stand; ein falsch belegter
/// sieht dann aus wie ein Tippfehler. Im Vordergrund stehen soll sie nicht —
/// wer schreibt, schreibt.
class PlatzhalterUebersicht extends StatelessWidget {
  const PlatzhalterUebersicht({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
      buildWhen: (vorher, jetzt) =>
          vorher.gewaehlteVorlage != jetzt.gewaehlteVorlage ||
          vorher.zusatzgruss != jetzt.zusatzgruss ||
          vorher.entwurf.alleEmpfaenger != jetzt.entwurf.alleEmpfaenger,
      builder: (context, stand) {
        final vorlage = stand.gewaehlteVorlage;
        if (vorlage == null) return const SizedBox.shrink();

        final befunde = context
            .read<EmailEntwurfCubit>()
            .fuellerFuer(stand.entwurf.alleEmpfaenger)
            .befunde(vorlage);
        if (befunde.isEmpty) return const SizedBox.shrink();

        final leere = befunde.where((befund) => befund.istLeer).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Theme(
            // Ohne Trennlinien fügt sich der Aufklapper in das Formular ein,
            // statt es in zwei Hälften zu schneiden.
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              dense: true,
              title: Text(
                leere == 0
                    ? 'Platzhalter (${befunde.length})'
                    : 'Platzhalter (${befunde.length}, davon $leere leer)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: TextButton.icon(
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Vorlagentext'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => VorlagentextDialog(vorlage: vorlage),
                ),
              ),
              children: [
                for (final befund in befunde) PlatzhalterZeile(befund: befund),
              ],
            ),
          ),
        );
      },
    );
  }
}
