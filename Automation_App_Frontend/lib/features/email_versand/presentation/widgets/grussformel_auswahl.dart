import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Wahl des persönlichen Zusatzgrußes je Mail (§4.7) — Chips über dem
/// Betreff, vorbelegt mit dem, was am Mandanten hinterlegt ist (§5.1). Die
/// Liste selbst pflegt der Anwalt in den Einstellungen (§7.1).
///
/// **Der Empfängerkreis sperrt hier nichts mehr** (geändert am 02.09.2026):
/// Der Gruß geht mit, wo die Vorlage den Platzhalter `{{Zusatzgruß}}` trägt.
/// Steht die Gegenseite mit im Feld „An", sagt der Abschnitt das — entscheiden
/// darf der Anwalt. Bis dahin war es umgekehrt gesperrt, und ein
/// Mandantenanschreiben mit einer Adresse in Kopie verlor den Gruß wortlos.
///
/// **Sichtbar gesperrt statt still weggelassen** bleibt für den einen Fall, in
/// dem die Wahl nachweislich nichts bewirkt: Die gewählte Vorlage hat gar
/// keine Stelle für den Gruß. Dann steht die Reihe still da und nennt den
/// Grund, statt zu verschwinden.
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

  /// Der Satz unter den Chips — oder null, wenn nichts zu sagen ist.
  ///
  /// Zwei verschiedene Auskünfte, und nur eine davon ist ein Hindernis: Die
  /// Vorlage ohne Platzhalter **verhindert** den Gruß, der Mitleser nicht.
  static String? hinweisFuer(EmailEntwurfState entwurf) {
    if (!entwurf.grussMoeglich) {
      return 'Die gewählte Vorlage hat keine Stelle dafür — dazu gehört der '
          'Platzhalter {{${MailPlatzhalter.zusatzgruss}}} in den Vorlagentext '
          '(Einstellungen ▸ E-Mail).';
    }
    if (entwurf.mitleserImAn && entwurf.zusatzgruss.isNotEmpty) {
      return 'Neben dem Mandanten steht noch jemand im Feld „An" oder in '
          'Kopie — der Gruß geht trotzdem mit.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<GrussformelnCubit, GrussformelnState>(
      builder: (context, bestand) {
        return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
          buildWhen: (vorher, jetzt) =>
              vorher.zusatzgruss != jetzt.zusatzgruss ||
              vorher.grussMoeglich != jetzt.grussMoeglich ||
              vorher.mitleserImAn != jetzt.mitleserImAn ||
              vorher.beschaeftigt != jetzt.beschaeftigt,
          builder: (context, entwurf) {
            // Kein Bestand und nichts gewählt: nichts anzeigen. Eine leere
            // Chipreihe sähe aus wie eine Einstellung, die es nicht gibt.
            if (bestand.grussformeln.isEmpty && entwurf.zusatzgruss.isEmpty) {
              return const SizedBox.shrink();
            }

            final cubit = context.read<EmailEntwurfCubit>();
            final aktiv = entwurf.grussMoeglich && !entwurf.beschaeftigt;
            final hinweis = hinweisFuer(entwurf);

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
                  if (hinweis != null)
                    Text(
                      hinweis,
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
