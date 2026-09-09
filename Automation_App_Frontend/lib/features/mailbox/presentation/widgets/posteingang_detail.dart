import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosteingangDetail extends StatelessWidget {
  final PosteingangState state;
  const PosteingangDetail({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final mail = state.auswahl;
    if (mail == null) {
      return const Center(child: Text('Eine Nachricht zum Lesen auswählen.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            mail.betreff,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SelectableText(mail.absender),
          const Divider(height: 24),
          if (state.inhaltLaedt) const LinearProgressIndicator(),
          if (state.inhaltFehler != null) ...[
            Text(state.inhaltFehler!),
            TextButton(
              onPressed: () => context.read<PosteingangCubit>().oeffnen(mail),
              child: const Text('Erneut versuchen'),
            ),
          ],
          if (state.inhalt case final inhalt?) ...[
            if (inhalt.gekuerzt)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Die Vorschau ist begrenzt. Den vollständigen Text findest du im Webmailer.',
                ),
              ),
            SelectableText(
              inhalt.text.isEmpty ? '(Kein Mailtext)' : inhalt.text,
            ),
            if (inhalt.anhaenge.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Anhänge', style: Theme.of(context).textTheme.titleMedium),
              for (final name in inhalt.anhaenge) Text(name),
              const SizedBox(height: 8),
              const Text(
                'Anhänge werden hier nicht heruntergeladen. Sie sind im Webmailer verfügbar.',
              ),
            ],
          ],
        ],
      ),
    );
  }
}
