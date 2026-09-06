import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/vorlagen_kopie_cubit/vorlagen_kopie_cubit.dart';
import 'package:automation_app/features/form_template_setup/presentation/views/form_template_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class FormTemplateManagementPage extends StatelessWidget
    implements AutoRouteWrapper {
  const FormTemplateManagementPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return PageRefreshScope(
      builder: (context) => MultiBlocProvider(
        providers: [
          // Singleton-Bloc: per .value einbinden, damit er beim Dispose der
          // Seite nicht geschlossen wird.
          BlocProvider.value(
            value: getIt<FormTemplateOverviewBloc>()
              ..add(LoadFormTemplatesEvent()),
          ),
          // Duplizieren lebt nur, solange diese Seite offen ist — anders als
          // der Overview-Bloc, den sich der Wizard mitliest (siehe
          // `VorlagenKopieCubit`).
          BlocProvider(create: (_) => getIt<VorlagenKopieCubit>()),
        ],
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const SeitenAppBar(
        titel: 'Formularvorlagen verwalten',
        icon: Icons.drive_file_rename_outline_outlined,
        untertitel: 'Beschreiben, welche Felder eine Word-Vorlage hat',
        aktionen: [PageRefreshButton()],
      ),
      // Duplizieren meldet sich hier und nicht in der Zeile: Die Zeile, die den
      // Knopf trägt, ist nach dem Neuladen der Liste eine andere — ihr Kontext
      // wäre beim Eintreffen der Meldung schon abgebaut.
      body: BlocListener<VorlagenKopieCubit, VorlagenKopieState>(
        listener: _meldeKopie,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Eine Vorlage beschreibt die Felder einer Word-Vorlage und '
                      'bestimmt damit das Formular beim Ausfüllen.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 16),
                  CustomRectangularButton(
                    onPressed: () async {
                      final didChange = await context.router.push<bool>(
                        FormTemplateDetailsRoute(),
                      );
                      if (didChange == true && context.mounted) {
                        context.read<FormTemplateOverviewBloc>().add(
                          LoadFormTemplatesEvent(),
                        );
                      }
                    },
                    label: Text(
                      'Neue Vorlage erstellen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Expanded(
                child:
                    BlocBuilder<
                      FormTemplateOverviewBloc,
                      FormTemplateOverviewState
                    >(
                      builder: (context, state) {
                        return switch (state) {
                          FormTemplateOverviewLoading() => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          FormTemplateOverviewLoaded() => FormTemplateOverview(
                            state: state,
                          ),
                          FormTemplateOverviewError() => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 12,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: theme.colorScheme.error,
                                ),
                                Text(
                                  state.message,
                                  textAlign: TextAlign.center,
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => context
                                      .read<FormTemplateOverviewBloc>()
                                      .add(LoadFormTemplatesEvent()),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Erneut versuchen'),
                                ),
                              ],
                            ),
                          ),
                        };
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Was nach dem Duplizieren zu sehen ist. Der Erfolg sagt den **neuen**
  /// Namen — er ist nicht der, den der Anwalt angeklickt hat — und den einen
  /// Schritt, der der Kopie noch fehlt. Danach lädt die Übersicht neu, genau
  /// wie nach dem Anlegen einer Vorlage.
  ///
  /// Der Fehlerfall ist im Alltag die Namens-Dublette (409), die der Dienst
  /// erzwingt: Sie kommt als Meldung, nicht als leere Liste.
  void _meldeKopie(BuildContext context, VorlagenKopieState zustand) {
    switch (zustand) {
      case VorlagenKopieErfolg(name: final name):
        Rueckmeldung.zeigeErfolg(
          context,
          'Vorlage „$name" angelegt — Word-Dateien noch zuweisen.',
        );
        context.read<FormTemplateOverviewBloc>().add(LoadFormTemplatesEvent());
      case VorlagenKopieFehler(meldung: final meldung):
        Rueckmeldung.zeigeFehler(context, meldung);
      case VorlagenKopieRuht():
      case VorlagenKopieLaeuft():
        break;
    }
  }
}
