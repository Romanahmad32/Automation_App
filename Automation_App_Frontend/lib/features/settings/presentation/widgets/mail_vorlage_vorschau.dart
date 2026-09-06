import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlage_beispiel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau.dart';
import 'package:flutter/material.dart';

/// Die mitlaufende Vorschau im Vorlageneditor: die Vorlage, **mit
/// Beispieldaten gefüllt** (§4.7, ergänzt am 06.09.2026).
///
/// **Dieselbe Ansicht wie im Versanddialog** ([EmailVorschau]) — und das ist
/// der Punkt: Was der Anwalt hier sieht, ist die Mail, wie sie ankommt, nicht
/// eine zweite Darstellung derselben Sache. Gefüllt wird über denselben
/// `MailVorlagenFueller`, den auch der Versand benutzt; eine eigene Rechnung
/// hier wäre genau die, die eines Tages von der echten abweicht.
///
/// **Zieht beim Tippen nach**, über die Controller der beiden Felder — wie
/// `VorlagenHinweise`. Ein eigenes `setState` im Dialog wäre der zweite Weg
/// zum selben Ziel, und nur dieser Block muss neu bauen.
class MailVorlageVorschau extends StatelessWidget {
  final TextEditingController betreff;
  final TextEditingController text;

  const MailVorlageVorschau({
    super.key,
    required this.betreff,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([betreff, text]),
      builder: (context, _) {
        final gefuellt = MailVorlageBeispiel.fueller().fuelleVorlage(
          MailVorlage(betreff: betreff.text, text: text.text),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 6,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                // Umbrechbar: Die Spalte ist schmal, und bei angehobenem
                // Schriftgrad (§7.1) liefe die Zeile sonst über den Rand.
                Expanded(
                  child: Text(
                    'Vorschau — so wird die Vorlage zur Mail',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                // Rechts schmal: Dort läuft die Bildlaufleiste der Vorschau.
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: EmailVorschau(
                  entwurf: EmailEntwurf(
                    an: const [MailVorlageBeispiel.empfaenger],
                    betreff: gefuellt.betreff,
                    text: gefuellt.text,
                  ),
                  absender: MailVorlageBeispiel.absender,
                  signaturHinweis: MailVorlageBeispiel.hinweis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
