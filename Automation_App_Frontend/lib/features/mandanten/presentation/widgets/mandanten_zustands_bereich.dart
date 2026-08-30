import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_fehler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Nimmt Laden, Fehler und Neuladen des [MandantenOverviewBloc] ab; [builder]
/// bekommt nur den geladenen Zustand. Beide Mandantenseiten — Übersicht und
/// Zuordnungsstapel — hängen am selben Bloc und sollen sich dabei gleich
/// verhalten.
///
/// Beim Neuladen bleibt der bisherige Stand stehen und bekommt nur einen
/// Fortschrittsbalken: bei tausenden Ordnern wäre ein Spinner statt der Liste
/// nach jeder Zuordnung ein verlorener Scrollstand.
///
/// Dasselbe gilt für eine gescheiterte Einzelaktion — sie erscheint als
/// Meldung über der Liste. Das ganze Fehlerbild (`MandantenFehler`) bleibt
/// dem Fall vorbehalten, in dem es wirklich nichts zu zeigen gibt: wenn schon
/// das Laden fehlgeschlagen ist.
class MandantenZustandsBereich extends StatelessWidget {
  final Widget Function(BuildContext context, MandantenOverviewLoaded state)
  builder;

  const MandantenZustandsBereich({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MandantenOverviewBloc, MandantenOverviewState>(
      builder: (context, state) => switch (state) {
        MandantenOverviewLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        MandantenOverviewError() => MandantenFehler(message: state.message),
        MandantenOverviewLoaded() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 4,
              child: state.neuLadend
                  ? const LinearProgressIndicator(minHeight: 4)
                  : null,
            ),
            if (state.fehler != null) _meldung(context, state.fehler!),
            Expanded(child: builder(context, state)),
          ],
        ),
      },
    );
  }

  Widget _meldung(BuildContext context, String fehler) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(child: FehlerHinweis(nachricht: fehler)),
        IconButton(
          onPressed: () => context.read<MandantenOverviewBloc>().add(
            const FehlerVerwerfenEvent(),
          ),
          icon: const Icon(Icons.close),
          tooltip: 'Meldung schließen',
        ),
      ],
    ),
  );
}
