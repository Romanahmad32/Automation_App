import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_originaltext_panel.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_vorgang_zuordnung.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/manual_reply_input.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Rechte Seite: manuelles Eingabepanel bzw. dessen Ergebnis, ein ausgewählter
/// Treffer oder ein Platzhalter.
class MailboxDetailPane extends StatelessWidget {
  final bool manualMode;
  final ReceivedReply? selected;
  final void Function(
    ReceivedReply reply,
    ZentralrufReplyData daten,
    String? zielReferenz,
  )
  onTrefferUebernehmen;
  final void Function(ZentralrufReplyData daten, String? zielReferenz)
  onManuellUebernehmen;

  const MailboxDetailPane({
    super.key,
    required this.manualMode,
    required this.selected,
    required this.onTrefferUebernehmen,
    required this.onManuellUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    if (manualMode) {
      final state = context.watch<ZentralrufReplyBloc>().state;
      return switch (state) {
        ZentralrufReplyParsed(result: final result) => VorgangsdatenForm(
          key: ObjectKey(result),
          data: result.data,
          warnings: result.warnings,
          onUebernehmen: onManuellUebernehmen,
        ),
        ZentralrufReplyError(message: final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        _ => const ManualReplyInput(),
      };
    }

    if (selected case final reply?) {
      final theme = Theme.of(context);
      return VorgangsdatenForm(
        key: ValueKey(reply.id),
        data: reply.data,
        warnings: reply.warnings,
        onUebernehmen: (daten, zielReferenz) =>
            onTrefferUebernehmen(reply, daten, zielReferenz),
        kopf: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Erfasste Antwort', style: theme.textTheme.titleMedium),
            if (reply.subject case final subject?) ...[
              const SizedBox(height: 4),
              Text(subject, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            MailboxVorgangZuordnung(antwortDaten: reply.data),
          ],
        ),
        fuss: MailboxOriginaltextPanel(rawText: reply.rawText),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Eine Antwort links auswählen oder „Manuell einfügen", um die '
          'erkannten Daten zu prüfen und zu übernehmen.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
