import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_inbox_view.dart';
import 'package:automation_app/features/mailbox/presentation/views/posteingang_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MailboxBereiche extends StatefulWidget {
  const MailboxBereiche({super.key});
  @override
  State<MailboxBereiche> createState() => _MailboxBereicheState();
}

class _MailboxBereicheState extends State<MailboxBereiche> {
  final _signal = getIt<MailboxAuswahlSignal>();
  bool _zentralruf = false;

  @override
  void initState() {
    super.initState();
    _zentralruf = _signal.pendingReplyId.value != null;
    _signal.pendingReplyId.addListener(_zeigeAntwort);
  }

  void _zeigeAntwort() {
    if (_signal.pendingReplyId.value != null && !_zentralruf) {
      setState(() => _zentralruf = true);
    }
  }

  @override
  void dispose() {
    _signal.pendingReplyId.removeListener(_zeigeAntwort);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Posteingang'),
              icon: Icon(Icons.inbox_outlined),
            ),
            ButtonSegment(value: true, label: Text('Zentralruf-Antworten')),
          ],
          selected: {_zentralruf},
          onSelectionChanged: (value) =>
              setState(() => _zentralruf = value.first),
        ),
      ),
      Expanded(
        child: _zentralruf
            ? BlocProvider(
                create: (_) => getIt<MailboxInboxCubit>()..refresh(),
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () =>
                              context.read<MailboxInboxCubit>().refresh(),
                          tooltip: 'Zentralruf-Antworten aktualisieren',
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                    const Expanded(child: MailboxInboxView()),
                  ],
                ),
              )
            : BlocProvider(
                create: (_) => getIt<PosteingangCubit>()..aktualisieren(),
                child: const PosteingangView(),
              ),
      ),
    ],
  );
}
