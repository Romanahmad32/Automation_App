import 'package:auto_route/auto_route.dart';
import 'package:injectable/injectable.dart';

import 'app_router.gr.dart';

@singleton
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: AppShellRoute.page,
      children: [
        // Erster Eintrag = Start-Tab: die Übersicht empfängt den Anwalt.
        AutoRoute(path: 'uebersicht', page: DashboardRoute.page),
        AutoRoute(path: 'word-automation', page: WordAutomationRoute.page),
        AutoRoute(path: 'vorgang-starten', page: VorgangStartenRoute.page),
        AutoRoute(path: 'postfach', page: MailboxInboxRoute.page),
        AutoRoute(
          path: 'vorlagen-verwalten',
          page: FormTemplateManagementStackRoute.page,
          children: [
            AutoRoute(path: '', page: FormTemplateManagementRoute.page),
            AutoRoute(path: 'details', page: FormTemplateDetailsRoute.page),
          ],
        ),
        AutoRoute(
          path: 'mandanten',
          page: MandantenStackRoute.page,
          children: [
            AutoRoute(path: '', page: MandantenOverviewRoute.page),
            AutoRoute(path: 'details', page: MandantDetailsRoute.page),
            AutoRoute(
              path: 'zuordnung',
              page: NichtZugeordneteOrdnerRoute.page,
            ),
            AutoRoute(path: 'import', page: MandantenImportRoute.page),
          ],
        ),
        AutoRoute(path: 'register', page: RegisterRoute.page),
        AutoRoute(
          path: 'vorgaenge-verwalten',
          page: VorgaengeVerwaltenRoute.page,
        ),
        AutoRoute(path: 'einstellungen', page: SettingsRoute.page),
      ],
    ),
  ];
}
