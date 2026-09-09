import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_datetime_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosteingangListe extends StatelessWidget {
  final PosteingangState state;
  const PosteingangListe({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final mails = state.seite?.nachrichten ?? [];
    final cubit = context.read<PosteingangCubit>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Seite ${state.seitennummer} · ${state.seite?.gesamt ?? 0} Nachrichten',
              ),
              IconButton(
                onPressed: state.laedt ? null : cubit.aktualisieren,
                tooltip: 'Neueste Nachrichten laden',
                icon: const Icon(Icons.refresh),
              ),
              if (state.neueNachrichten)
                TextButton(
                  onPressed: state.laedt ? null : cubit.aktualisieren,
                  child: const Text('Neue Nachrichten laden'),
                ),
            ],
          ),
        ),
        if (state.laedt) const LinearProgressIndicator(),
        if (state.fehler != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(state.fehler!),
          ),
        Expanded(
          child: mails.isEmpty
              ? Center(
                  child: Text(
                    state.laedt
                        ? 'Nachrichten werden geladen …'
                        : state.fehler != null
                        ? 'Bitte erneut laden.'
                        : 'Keine Nachrichten im Posteingang.',
                  ),
                )
              : ListView.builder(
                  key: ValueKey(state.seitennummer),
                  itemCount: mails.length,
                  itemBuilder: (context, index) {
                    final mail = mails[index];
                    return ListTile(
                      selected: state.auswahl?.id == mail.id,
                      enabled: !state.laedt,
                      leading: Icon(
                        mail.gelesen
                            ? Icons.drafts_outlined
                            : Icons.mark_email_unread_outlined,
                      ),
                      title: Text(
                        mail.betreff,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${mail.absender}\n${mail.datum == null ? '' : formatMailboxDateTime(mail.datum!)}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => cubit.oeffnen(mail),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: state.laedt || state.seitennummer == 1
                    ? null
                    : cubit.neuere,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Neuere'),
              ),
              OutlinedButton.icon(
                onPressed: state.laedt || state.seite?.naechsteSeite == null
                    ? null
                    : cubit.aeltere,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Ältere'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
