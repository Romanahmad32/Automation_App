import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fehlerbild der Mandantenseiten samt „Erneut versuchen" — löst dasselbe
/// Ladeereignis aus wie der Seitenaufbau.
class MandantenFehler extends StatelessWidget {
  final String message;

  const MandantenFehler({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          Text(message, textAlign: TextAlign.center),
          OutlinedButton.icon(
            onPressed: () => context.read<MandantenOverviewBloc>().add(
              const LoadMandantenUebersichtEvent(),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }
}
