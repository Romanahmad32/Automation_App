import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Wahl des persönlichen Zusatzgrußes je Mail (§4.7) — Chips über dem
/// Betreff, vorbelegt mit dem, was am Mandanten hinterlegt ist (§5.1).
///
/// **Sichtbar gesperrt statt still weggelassen:** Steht noch jemand anderes im
/// Feld „An", geht der Gruß nicht mit — und dann sagt der Abschnitt das, statt
/// ihn wortlos verschwinden zu lassen. Ein persönlicher Gruß, den die
/// gegnerische Versicherung mitliest, wäre keiner.
class GrussformelAuswahl extends StatelessWidget {
  const GrussformelAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<GrussformelnCubit>()..ladenWennNoetig(),
      child: const GrussformelChips(),
    );
  }
}

/// Die Chips selbst, unter dem bereitgestellten [GrussformelnCubit].
class GrussformelChips extends StatelessWidget {
  const GrussformelChips({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<GrussformelnCubit, GrussformelnState>(
      builder: (context, bestand) {
        return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
          buildWhen: (vorher, jetzt) =>
              vorher.zusatzgruss != jetzt.zusatzgruss ||
              vorher.grussMoeglich != jetzt.grussMoeglich ||
              vorher.beschaeftigt != jetzt.beschaeftigt,
          builder: (context, entwurf) {
            // Kein Bestand und nichts gewählt: nichts anzeigen. Eine leere
            // Chipreihe sähe aus wie eine Einstellung, die es nicht gibt.
            if (bestand.grussformeln.isEmpty && entwurf.zusatzgruss.isEmpty) {
              return const SizedBox.shrink();
            }

            final cubit = context.read<EmailEntwurfCubit>();
            final aktiv = entwurf.grussMoeglich && !entwurf.beschaeftigt;

            // Was am Mandanten steht, kann im Bestand fehlen — dann gehört es
            // trotzdem in die Reihe, sonst verschwindet die Vorbelegung.
            final texte = <String>[
              for (final gruss in bestand.grussformeln) gruss.text,
              if (entwurf.zusatzgruss.isNotEmpty &&
                  !bestand.grussformeln.any(
                    (gruss) => gruss.text == entwurf.zusatzgruss,
                  ))
                entwurf.zusatzgruss,
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('Zusatzgruß', style: theme.textTheme.labelLarge),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('kein'),
                        selected: entwurf.zusatzgruss.isEmpty,
                        onSelected: aktiv
                            ? (_) => cubit.setzeZusatzgruss('')
                            : null,
                      ),
                      for (final text in texte)
                        ChoiceChip(
                          label: Text(text),
                          selected: entwurf.zusatzgruss == text,
                          onSelected: aktiv
                              ? (gewaehlt) =>
                                    cubit.setzeZusatzgruss(gewaehlt ? text : '')
                              : null,
                        ),
                    ],
                  ),
                  if (!entwurf.grussMoeglich)
                    Text(
                      'Geht nur, wenn ausschließlich der Mandant angeschrieben '
                      'wird — sonst läse die Gegenseite mit.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
