import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/general_widgets/drawer/app_side_bar.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_persistenz_fehler_listener.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  bool _isExtended = false;

  static const _collapsedWidth = 72.0;

  // 16 px breiter als früher (204 -> 220 -> 236 Innenraum): Bei der Stufe
  // „Am größten" (Issue #57) lief „Vorlagen Verwalten" um rund 8 px über den
  // rechten Rand. Das Ellipsis in `SidebarItem` fängt einen Überlauf zwar
  // sicher ab, aber die längste Beschriftung soll vollständig lesbar bleiben
  // statt beschnitten zu werden — ein paar Pixel mehr Breite sind der
  // günstigere Tausch als eine gekürzte Beschriftung im Alltag.
  static const _expandedWidth = 236.0;
  static const _animationDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: [
        const DashboardRoute(),
        const VorgangStartenRoute(),
        const MailboxInboxRoute(),
        const WordAutomationRoute(),
        const FormTemplateManagementStackRoute(),
        const MandantenStackRoute(),
        const RegisterRoute(),
        const VorgaengeVerwaltenRoute(),
        SettingsRoute(),
      ],
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        return Scaffold(
          body: Row(
            children: [
              AppSidebar(
                isExtended: _isExtended,
                collapsedWidth: _collapsedWidth,
                expandedWidth: _expandedWidth,
                animationDuration: _animationDuration,
                activeIndex: tabsRouter.activeIndex,
                onDestinationSelected: tabsRouter.setActiveIndex,
                onToggle: () => setState(() => _isExtended = !_isExtended),
              ),
              Expanded(child: VorgangPersistenzFehlerListener(child: child)),
            ],
          ),
        );
      },
    );
  }
}
