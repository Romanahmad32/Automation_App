import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Anredeart je Mail (§4.7, ergänzt am 02.09.2026) — Chips über der
/// Anrede, vorbelegt aus dem Mandantenregister (§5.1).
///
/// Sie steht **über** der Anredeauswahl, weil sie sie beugt: „Sehr geehrt**er**
/// Herr" gegen „Sehr geehrt**e** Frau". Und sie beugt den Vorlagentext —
/// `{{Mandant/Mandantin}}` wird hier entschieden. Das ist der Grund, warum die
/// Reihe **immer** steht und nicht nur bei einer Mail an den Mandanten: Eine
/// Mail an die Versicherung beginnt mit „Sehr geehrte Damen und Herren" und
/// schreibt im Text trotzdem von „unserer Mandantin".
///
/// Weil die Reihe **immer** steht, steht sie auch in Lagen, in denen sie
/// nichts bewegt. Deshalb sagt der Satz darunter, worauf sie **jetzt** wirkt
/// ([AnredeartWirkung]) — ein festes „beugt Anrede und Text" war in der
/// häufigsten Mail dieser Kanzlei eine Behauptung ohne Deckung.
///
/// Gilt nur für diese Mail: In den Mandantendatensatz wird nichts
/// zurückgeschrieben (§1.3) — deshalb sagt die Reihe es, wenn die Wahl vom
/// Register abweicht.
class GeschlechtAuswahl extends StatelessWidget {
  const GeschlechtAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
      buildWhen: (vorher, jetzt) =>
          vorher.geschlecht != jetzt.geschlecht ||
          vorher.anredeGeschlecht != jetzt.anredeGeschlecht ||
          vorher.mandantAnrede != jetzt.mandantAnrede ||
          vorher.mandantBekannt != jetzt.mandantBekannt ||
          // Seit der Satz sagt, worauf die Anredeart **jetzt** wirkt, hängt er
          // an allem, was das ändert: die Vorlage (sie trägt die gebeugten
          // Wörter und die Stelle für die Anrede) und alles, was die
          // Anredezeile neutral macht.
          vorher.gewaehlteVorlage != jetzt.gewaehlteVorlage ||
          vorher.anredeNeutral != jetzt.anredeNeutral ||
          vorher.anredePersoenlichMoeglich != jetzt.anredePersoenlichMoeglich ||
          // `!=` verglich zwei frisch gebaute Listen über die Identität und
          // war damit immer wahr (behoben am 03.09.2026, siehe
          // `PlatzhalterUebersicht.neuZeichnen`).
          !listEquals(
            vorher.entwurf.alleEmpfaenger,
            jetzt.entwurf.alleEmpfaenger,
          ) ||
          vorher.beschaeftigt != jetzt.beschaeftigt,
      builder: (context, state) {
        final cubit = context.read<EmailEntwurfCubit>();
        final aktiv = !state.beschaeftigt;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('Anredeart', style: theme.textTheme.labelLarge),
              // Was sie **jetzt** bewegt, nicht was sie im Allgemeinen kann
              // (geändert am 02.09.2026): Hier stand „Beugt die Anrede und die
              // Wortformen im Text" — ein Versprechen, das die häufigste Mail
              // dieser Kanzlei nicht einlöst, weil ihre Anrede neutral ist und
              // ihre Vorlage kein gebeugtes Wort trägt.
              Text(
                cubit.anredeartWirkung.hinweis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final anrede in Anrede.values)
                    ChoiceChip(
                      label: Text(anrede.displayName),
                      selected: state.geschlecht == anrede,
                      onSelected: aktiv
                          ? (_) => cubit.waehleGeschlecht(anrede)
                          : null,
                    ),
                ],
              ),
              if (state.anredeartWeichtAb)
                Text(
                  'Abweichend vom Mandantenregister — gilt nur für diese Mail.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (state.anredeartNachtragbar)
                AnredeartNachtragen(
                  aktiv: aktiv,
                  onNachtragen: cubit.merkeAnredeart,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Das Angebot, die gewählte Anredeart im Mandantenregister nachzutragen
/// (§4.7, §5.1) — wenn dort **keine** steht.
///
/// Der Grund für den Knopf: Ohne ihn wählt der Anwalt bei jeder Mail an diesen
/// Mandanten von Hand, und die Lücke im Register bleibt für immer. Sie fällt
/// hier auf, also lässt sie sich hier beheben.
///
/// Ein Angebot und keine Automatik (§1.3): Dass der Anwalt für **diese** Mail
/// „Frau" wählt, ist noch keine Ansage, die Stammdaten zu ändern — nur der
/// Klick ist eine. Eine bereits hinterlegte Anredeart erscheint hier gar
/// nicht, die wird im Register korrigiert.
class AnredeartNachtragen extends StatelessWidget {
  final bool aktiv;
  final VoidCallback onNachtragen;

  const AnredeartNachtragen({
    super.key,
    required this.aktiv,
    required this.onNachtragen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Text(
            'Am Mandanten ist keine Anredeart hinterlegt — dann steht diese '
            'Wahl bei jeder Mail an ihn wieder aus.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: aktiv ? onNachtragen : null,
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Im Register hinterlegen'),
        ),
      ],
    );
  }
}
