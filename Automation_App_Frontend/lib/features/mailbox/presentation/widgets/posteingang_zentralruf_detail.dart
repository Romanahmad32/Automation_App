import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_datetime_format.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_originaltext_panel.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_vorgang_zuordnung.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_form.dart';
import 'package:flutter/material.dart';

/// Detail einer Posteingangs-Zeile, die zu einer bereits erfassten
/// Zentralruf-Antwort gehört (Variante B, Issue #134): Statt des Mailtexts
/// zeigt das Panel denselben Inhalt wie bisher der eigene Bereich
/// „Zentralruf-Antworten" — das editierbare [VorgangsdatenForm] samt
/// Konfliktbehandlung über [onUebernehmen] und dem darin bereits eingebauten
/// Zwischennachricht-Hinweis, dazu die Vorgangszuordnung. Nichts davon wird
/// kopiert, nur mit einem eigenen Kopf neu zusammengesetzt.
class PosteingangZentralrufDetail extends StatelessWidget {
  final ReceivedReply antwort;

  /// Wird mit der (ggf. im Formular korrigierten) Antwort aufgerufen, wenn
  /// der Anwalt „Übernehmen" drückt. Konfliktprüfung, das tatsächliche
  /// Übernehmen in den Vorgang und der Tab-Wechsel bleiben Sache des
  /// Aufrufers — genau wie bisher bei `MailboxDetailPane.onTrefferUebernehmen`,
  /// dessen Signatur diese Funktion deshalb spiegelt.
  final void Function(
    ReceivedReply antwort,
    ZentralrufReplyData daten,
    String? zielReferenz,
  )
  onUebernehmen;

  /// Wechselt von diesem Zentralruf-Detail zur normalen Mailansicht derselben
  /// Zeile („Mail anzeigen").
  final VoidCallback onMailAnzeigen;

  const PosteingangZentralrufDetail({
    super.key,
    required this.antwort,
    required this.onUebernehmen,
    required this.onMailAnzeigen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versicherer = (antwort.data.versichererName ?? '').trim();

    return VorgangsdatenForm(
      key: ValueKey(antwort.id),
      data: antwort.data,
      warnings: antwort.warnings,
      onUebernehmen: (daten, zielReferenz) =>
          onUebernehmen(antwort, daten, zielReferenz),
      kopf: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap statt Row: Bei „Am größten" (Issue #57) und schmalem Fenster
          // reicht die Breite nicht mehr für Pille, Versicherer, Datum und den
          // Knopf nebeneinander — Wrap reiht sie in mehreren Zeilen statt
          // überzulaufen.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPille(
                text: antwort.acknowledged
                    ? 'Zentralruf-Antwort · übernommen'
                    : 'Zentralruf-Antwort · offen',
                // Ocker statt einer Theme-Rolle (bewusste Gestaltentscheidung
                // zu Issue #134) — dieselbe Farbe wie der gleichnamige Chip
                // in der Liste.
                farbe: const Color(0xFFB8860B),
              ),
              if (versicherer.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    versicherer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Text(
                formatMailboxDateTime(antwort.receivedAt),
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                onPressed: onMailAnzeigen,
                child: const Text('Mail anzeigen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MailboxVorgangZuordnung(antwortDaten: antwort.data),
        ],
      ),
      fuss: MailboxOriginaltextPanel(rawText: antwort.rawText),
    );
  }
}
