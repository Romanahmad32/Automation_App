import 'package:automation_app/features/email_versand/domain/entities/anrede_neutral_grund.dart';
import 'package:flutter/material.dart';

/// Der Satz, der sagt, **warum** die Anrede neutral ist (§4.7, ergänzt am
/// 02.09.2026) — unter der Chipreihe, wo die Zeile zu sehen ist.
///
/// Er ist die Antwort auf einen Bericht aus der Kanzlei: „Sehr geehrte Damen
/// und Herren" stand über Mails, ohne dass jemand diese Anrede angelegt hatte,
/// und die Anredeart bewegte sie nicht. Beides war richtig; unsichtbar war der
/// Grund. Die App wusste ihn ([AnredeNeutralGrund]) und sagte ihn nicht.
///
/// **Ein Hinweis, keine Warnung** (§1.3): Der häufigste Grund ist der
/// Empfängerkreis, und dann ist die Mail in Ordnung. Nur die Lücken im
/// Register tragen das Zeichen — sie sind eine Aufgabe, der Rest ist eine
/// Auskunft.
class AnredeNeutralGrundZeile extends StatelessWidget {
  final AnredeNeutralGrund grund;

  const AnredeNeutralGrundZeile({super.key, required this.grund});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stil = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        if (grund.istLuecke)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        Expanded(child: Text(grund.hinweis, style: stil)),
      ],
    );
  }
}
