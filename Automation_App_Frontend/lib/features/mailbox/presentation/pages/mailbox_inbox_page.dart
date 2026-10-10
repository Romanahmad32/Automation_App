import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_bereiche.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_pille.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Postfach-Tab (REQUIREMENTS.md §4.3): der vollständige Posteingang, die
/// daraus automatisch erfassten Zentralruf-Antworten und der Blick auf das,
/// was die App versendet hat — in einer Ansicht.
///
/// Beide Blocs stehen hier und nicht in den Bereichen darunter: Der
/// [MailboxInboxCubit] versorgt zugleich die Statuspille in der Kopfzeile und
/// die Zentralruf-Kennzeichnung der Posteingangszeilen, der
/// [ZentralrufReplyBloc] den manuellen Weg, der als Dialog über beiden
/// Bereichen aufgeht.
///
/// Der Verbindungsstatus steht als Pille in der Kopfzeile statt als breites
/// Band über der Liste (`MailboxStatusBanner`, den weiterhin die Startseite
/// zeigt): Er ist eine Randbedingung, keine Nachricht — und ein Band kostete
/// dauerhaft die Höhe von zwei Posteingangszeilen.
@RoutePage()
class MailboxInboxPage extends StatelessWidget implements AutoRouteWrapper {
  const MailboxInboxPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ZentralrufReplyBloc>()),
        BlocProvider(create: (_) => getIt<MailboxInboxCubit>()..refresh()),
      ],
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
          untertitel: 'Posteingang, Zentralruf-Antworten und Versand',
          aktionen: [
            BlocBuilder<MailboxInboxCubit, MailboxInboxState>(
              builder: (context, state) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: MailboxStatusPille(
                  status: state.status,
                  error: state.error,
                ),
              ),
            ),
          ],
        ),
        body: const MailboxBereiche(),
      ),
    );
  }
}
