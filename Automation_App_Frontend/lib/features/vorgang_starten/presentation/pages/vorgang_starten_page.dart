import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/views/vorgang_starten_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class VorgangStartenPage extends StatelessWidget implements AutoRouteWrapper {
  const VorgangStartenPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return PageRefreshScope(
      builder: (context) => BlocProvider(
        create: (context) =>
            getIt<VorgangStartenBloc>()..add(const LadeDefaultsEvent()),
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VorgangStartenBloc, VorgangStartenState>(
      listener: (context, state) {
        if (state is VorgangStartenError) {
          Rueckmeldung.zeigeFehler(context, state.message);
        }
        if (state is MandantGespeichert) {
          Rueckmeldung.zeigeErfolg(
            context,
            state.warNeu
                ? 'Mandant „${state.mandant.anzeigename}" angelegt.'
                : 'Mandant „${state.mandant.anzeigename}" aktualisiert.',
          );
        }
        if (state is VorgangGespeichert) {
          final zeichen = ReferenzTeile.zeichenAus(state.referenz);
          if (state.zentralrufAusgefuellt) {
            // Enthält eine Handlungsanweisung (Captcha lösen, ein bewusster
            // Haltepunkt) — die braucht länger als die drei Sekunden einer
            // reinen Erfolgsmeldung.
            Rueckmeldung.zeigeHinweis(
              context,
              'Vorgang $zeichen gespeichert und Zentralruf-'
              'Formular vorausgefüllt. Bitte Captcha im '
              'Browserfenster lösen und absenden.',
              dauer: const Duration(seconds: 8),
            );
          } else {
            Rueckmeldung.zeigeErfolg(context, 'Vorgang $zeichen gespeichert.');
          }
        }
      },
      child: Scaffold(
        appBar: const SeitenAppBar(
          titel: 'Vorgang starten',
          icon: Icons.note_add_outlined,
          untertitel: 'Mandat erfassen und beim Zentralruf anfragen',
          aktionen: [PageRefreshButton()],
        ),
        body: const VorgangStartenFormView(),
      ),
    );
  }
}
