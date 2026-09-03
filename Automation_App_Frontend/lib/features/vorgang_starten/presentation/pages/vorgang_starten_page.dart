import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        if (state is MandantGespeichert) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.warNeu
                    ? 'Mandant „${state.mandant.anzeigename}" angelegt.'
                    : 'Mandant „${state.mandant.anzeigename}" aktualisiert.',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        if (state is VorgangGespeichert) {
          final zeichen = ReferenzTeile.zeichenAus(state.referenz);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.zentralrufAusgefuellt
                    ? 'Vorgang $zeichen gespeichert und Zentralruf-'
                          'Formular vorausgefüllt. Bitte Captcha im '
                          'Browserfenster lösen und absenden.'
                    : 'Vorgang $zeichen gespeichert.',
              ),
              duration: const Duration(seconds: 6),
            ),
          );
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
