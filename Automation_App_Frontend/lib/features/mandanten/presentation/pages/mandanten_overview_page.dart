import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class MandantenOverviewPage extends StatelessWidget
    implements AutoRouteWrapper {
  const MandantenOverviewPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return PageRefreshScope(
      builder: (context) => BlocProvider(
        create: (context) =>
            getIt<MandantenOverviewBloc>()..add(LoadMandantenUebersichtEvent()),
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mandanten'),
        centerTitle: true,
        actions: const [PageRefreshButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mandantenstammdaten und Akten. Die fertigen Dokumente '
                    'werden in der zugehörigen Akte abgelegt.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 16),
                CustomRectangularButton(
                  onPressed: () => _neuerMandant(context),
                  label: Text(
                    'Neuer Mandant',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt),
                ),
              ],
            ),
            Expanded(
              child: BlocBuilder<MandantenOverviewBloc, MandantenOverviewState>(
                builder: (context, state) {
                  return switch (state) {
                    MandantenOverviewLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    MandantenOverviewLoaded() => MandantenOverview(
                      state: state,
                    ),
                    MandantenOverviewError() => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 12,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          Text(state.message, textAlign: TextAlign.center),
                          OutlinedButton.icon(
                            onPressed: () => context
                                .read<MandantenOverviewBloc>()
                                .add(LoadMandantenUebersichtEvent()),
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
    );
  }

  Future<void> _neuerMandant(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final didChange = await context.router.push<bool>(MandantDetailsRoute());
    if (didChange == true) {
      bloc.add(LoadMandantenUebersichtEvent());
    }
  }
}
