import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sagt, was die Chips noch tun, sobald der Text von Hand bearbeitet ist
/// (§4.7, ergänzt am 02.09.2026) — und gibt den Weg zurück.
///
/// **Der Mangel, den das behebt:** Ab dem ersten eigenen Anschlag im Text hört
/// die Ableitung auf, damit die Handarbeit nicht beim nächsten Klick
/// verschwindet. Die Chipreihen darüber blieben dabei voll anfassbar und
/// liefen **still leer**: Wer die Anrede umstellte, sah nichts geschehen und
/// erfuhr auch nicht, warum.
///
/// Jetzt steht hier, was gilt: Anrede und Zusatzgruß werden an ihrer Stelle
/// weiter getauscht (`TextNachtrag`), Vorlage und Anredeart nicht mehr — die
/// eine schreibt den ganzen Text, die andere beugt Wörter mitten im Satz, und
/// beides wäre in einem selbst geschriebenen Text geraten.
///
/// Der Knopf ist die Rückfahrkarte. Er steht **hier** und nicht bei den Chips:
/// Ein Chip, der beim Klick den halben Text verwirft, wäre genau die
/// Überraschung, die die Sperre verhindern soll.
class HandarbeitHinweis extends StatelessWidget {
  const HandarbeitHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
      buildWhen: (vorher, jetzt) =>
          vorher.textSelbstGeschrieben != jetzt.textSelbstGeschrieben ||
          vorher.beschaeftigt != jetzt.beschaeftigt,
      builder: (context, state) {
        if (!state.textSelbstGeschrieben) return const SizedBox.shrink();
        final cubit = context.read<EmailEntwurfCubit>();
        // Derselbe Ton wie die übrigen Hinweise im Dialog — kein Alarmrot:
        // Ein selbst geschriebener Text ist kein Fehler, sondern der Regelfall
        // kurz vor dem Senden.
        final ton = theme.colorScheme.tertiary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Icon(Icons.edit_note_outlined, size: 18, color: ton),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Der Text ist von Hand bearbeitet.',
                      style: theme.textTheme.labelLarge?.copyWith(color: ton),
                    ),
                    Text(
                      HandarbeitHinweis.erklaerung,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: state.beschaeftigt ? null : cubit.erzeugeTextNeu,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Text neu erzeugen'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Was noch wirkt und was nicht. Öffentlich, weil ein Test darauf zeigt:
  /// Dieser Satz ist die ganze Auskunft, die vorher fehlte.
  static const String erklaerung =
      'Anrede und Zusatzgruß werden darin weiter getauscht. Eine andere '
      'Vorlage und eine andere Anredeart schreiben ihn nicht mehr um — dafür '
      'den Text neu erzeugen, die Bearbeitung geht dabei verloren.';
}
