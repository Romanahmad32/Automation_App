import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_inbox_view.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Vereinter Schritt der Antwort-Bearbeitung (REQUIREMENTS.md §4.3): automatisch
/// per Postfach erfasste Zentralruf-Antworten und der manuelle Weg (Mail
/// einfügen/laden) in einer Ansicht. Stellt beide zugehörigen Blocs bereit.
@RoutePage()
class MailboxInboxPage extends StatelessWidget implements AutoRouteWrapper {
  const MailboxInboxPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<MailboxInboxCubit>()..refresh()),
        BlocProvider(create: (_) => getIt<ZentralrufReplyBloc>()),
      ],
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ZentralrufReplyBloc, ZentralrufReplyState>(
      listener: (context, state) {
        if (state is ZentralrufReplyError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Postfach'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Aktualisieren',
              onPressed: () => context.read<MailboxInboxCubit>().refresh(),
            ),
          ],
        ),
        body: const MailboxInboxView(),
      ),
    );
  }
}
