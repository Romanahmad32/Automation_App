import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/views/nicht_zugeordnete_ordner_view.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_oeffnen_button.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_zustands_bereich.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eigene Seite für den Zuordnungsstapel. Bewusst nicht mehr als Abschnitt über
/// der Mandantenliste: im Produktivbestand liegen rund 4000 Ordner unter dem
/// Stammordner, die die eigentliche Liste sonst tausende Zeilen nach unten
/// schöben — und für Suche, Aktentyp und Zeitfenster ist dort kein Platz.
@RoutePage()
class NichtZugeordneteOrdnerPage extends StatelessWidget
    implements AutoRouteWrapper {
  const NichtZugeordneteOrdnerPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return PageRefreshScope(
      builder: (context) => BlocProvider(
        create: (context) =>
            getIt<MandantenOverviewBloc>()
              ..add(const LoadMandantenUebersichtEvent()),
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SeitenAppBar(
        titel: 'Ordner zuordnen',
        icon: Icons.rule_folder_outlined,
        untertitel: 'Gefundene Akten-Ordner einem Mandanten zuordnen',
        aktionen: [ImportOeffnenButton(), PageRefreshButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: MandantenZustandsBereich(
          builder: (context, state) => NichtZugeordneteOrdnerView(state: state),
        ),
      ),
    );
  }
}
