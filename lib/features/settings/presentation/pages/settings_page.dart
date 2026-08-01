import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/features/backup/presentation/views/data_backup_view.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_access_view.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/views/app_settings_view.dart';
import 'package:automation_app/features/settings/presentation/views/appearance_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class SettingsPage extends StatelessWidget implements AutoRouteWrapper {
  const SettingsPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return PageRefreshScope(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                getIt<KanzleiSettingsBloc>()
                  ..add(const LoadKanzleiSettingsEvent()),
          ),
          BlocProvider(
            create: (context) =>
                getIt<MailboxConfigBloc>()..add(const LoadMailboxConfigEvent()),
          ),
        ],
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Einstellungen'),
          centerTitle: true,
          actions: const [PageRefreshButton()],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.business), text: 'Kanzlei'),
              Tab(icon: Icon(Icons.mark_email_unread), text: 'Postfach-Zugang'),
              Tab(icon: Icon(Icons.palette_outlined), text: 'Darstellung'),
              Tab(icon: Icon(Icons.backup_outlined), text: 'Datensicherung'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AppSettingsView(),
            MailboxAccessView(),
            AppearanceSettingsView(),
            DataBackupView(),
          ],
        ),
      ),
    );
  }
}
