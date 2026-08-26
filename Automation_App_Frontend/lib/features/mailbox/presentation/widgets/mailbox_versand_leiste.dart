import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_button.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';

/// Der Einstieg zum Schreiben aus dem Postfach heraus (§4.7). Das Postfach ist
/// die Stelle, an der der Anwalt Korrespondenz vor sich hat — von hier aus muss
/// er antworten können, ohne den Umweg über den Word-Assistenten.
///
/// Ist ein Treffer gewählt und lässt sich seine Referenz einem Vorgang
/// zuordnen, ist der Entwurf damit vorbelegt (Empfänger, Betreff, Anrede).
/// Sonst entsteht ein leeres Anschreiben — Anrede und Grußformel stehen, den
/// Rest schreibt der Anwalt. Die Dateien, die an der erhaltenen Antwort hingen,
/// stehen dabei zum Anklicken bereit (§4.3) — beobachtet wurde, dass genau die
/// im Mailprogramm von Hand herübergezogen werden. Angehängt werden sie
/// trotzdem erst auf Klick: Was mitgeht, entscheidet der Anwalt.
class MailboxVersandLeiste extends StatelessWidget {
  final ReceivedReply? ausgewaehlt;

  const MailboxVersandLeiste({super.key, this.ausgewaehlt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reply = ausgewaehlt;
    final vorgang = reply == null
        ? null
        : getIt<VorgangCubit>().zielVorgangFuer(reply.data);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (vorgang != null)
            Flexible(
              child: Text(
                'Bezug: ${vorgang.referenz}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(width: 12),
          EmailVersandButton(
            vorgang: vorgang,
            antwort: reply?.data,
            // Die Anhänge der erhaltenen Antwort stehen zum Anklicken bereit,
            // hängen aber nicht von selbst dran (§4.3): Was mitgeht,
            // entscheidet der Anwalt — genau wie beim Fall-Ordner.
            ausDerAkte: reply?.anhangPfade ?? const [],
            beschriftung: 'E-Mail verfassen',
            beschriftungErneut: 'E-Mail verfassen',
          ),
        ],
      ),
    );
  }
}
