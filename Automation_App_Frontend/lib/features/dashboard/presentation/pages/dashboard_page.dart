import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Startseite der App: der Überblick, den der Anwalt beim Öffnen zuerst sieht —
/// welche Vorgänge auf eine Handlung warten, welche Zentralruf-Antworten noch
/// unbearbeitet im Postfach liegen und wo das Sachgebiete-Register steht.
///
/// Bewusst nur Anzeige und Absprung: bearbeitet wird in den jeweiligen Tabs.
@RoutePage()
class DashboardPage extends StatelessWidget implements AutoRouteWrapper {
  const DashboardPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    // Eigener Inbox-Cubit für die Startseite: er hängt selbst am SignalR-Hub,
    // eingehende Antworten erscheinen also ohne Zutun (wie im Postfach-Tab).
    return BlocProvider(
      create: (_) => getIt<MailboxInboxCubit>()..refresh(),
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SeitenAppBar(
        titel: 'Übersicht',
        icon: Icons.dashboard_outlined,
        untertitel: 'Was gerade auf eine Handlung wartet',
        aktionen: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () {
              context.read<MailboxInboxCubit>().refresh();
              getIt<VorgangCubit>().ladeErneut();
            },
          ),
        ],
      ),
      body: const DashboardView(),
    );
  }
}
