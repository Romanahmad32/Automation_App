import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_bereiche.dart';
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
      providers: [BlocProvider(create: (_) => getIt<ZentralrufReplyBloc>())],
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ZentralrufReplyBloc, ZentralrufReplyState>(
      listener: (context, state) {
        if (state is ZentralrufReplyError) {
          Rueckmeldung.zeigeFehler(context, state.message);
        }
      },
      child: Scaffold(
        appBar: SeitenAppBar(
          titel: 'Postfach',
          icon: Icons.mark_email_read_outlined,
          untertitel: 'Nachrichten lesen und Zentralruf-Antworten übernehmen',
        ),
        body: const MailboxBereiche(),
      ),
    );
  }
}
