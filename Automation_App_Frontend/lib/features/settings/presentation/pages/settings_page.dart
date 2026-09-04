import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/layout/traege_indexed_stack.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/backup/presentation/views/data_backup_view.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_access_view.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/views/app_settings_view.dart';
import 'package:automation_app/features/settings/presentation/views/appearance_settings_view.dart';
import 'package:automation_app/features/settings/presentation/views/ueber_settings_view.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_aktionszeile.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/views/standardpositionen_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Einstellungsseite: ein Seitenkopf, darunter sechs Abschnitte, von denen
/// immer einer sichtbar ist.
///
/// Die Abschnittswahl steht **nicht** hier, sondern in der
/// [EinstellungenAktionszeile], die jeder Reiter selbst zeichnet — warum, steht
/// dort. Diese Seite hält davon nur den [TabController]: Er ist das Band
/// zwischen der Auswahl in der Zeile und dem [TraegeIndexedStack] hier, und
/// weil `DefaultTabController` eine gewöhnliche Inherited ist, erreicht ihn
/// jeder Reiter, ohne dass er durchgereicht werden müsste.
///
/// Die Reihenfolge der Ansichten unten und die von
/// [EinstellungenAktionszeile.abschnitte] müssen übereinstimmen; der Index ist
/// das einzige Band dazwischen. `länge` kommt deshalb aus derselben Liste.
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
          // Reiter „Schadensaufstellung" (Feature word_automation).
          BlocProvider(
            create: (context) => getIt<StandardpositionenCubit>()..laden(),
          ),
        ],
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: EinstellungenAktionszeile.abschnitte.length,
      child: Scaffold(
        appBar: const SeitenAppBar(
          titel: 'Einstellungen',
          icon: Icons.settings_outlined,
          untertitel: 'Kanzleidaten, E-Mail und Darstellung',
          aktionen: [PageRefreshButton()],
        ),
        // Builder, damit `DefaultTabController.of` den Controller von oben
        // sieht und nicht im Kontext dieser Seite sucht.
        body: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) => TraegeIndexedStack(
                index: controller.index,
                children: const [
                  AppSettingsView(),
                  StandardpositionenSettingsView(),
                  MailboxAccessView(),
                  AppearanceSettingsView(),
                  DataBackupView(),
                  UeberSettingsView(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
