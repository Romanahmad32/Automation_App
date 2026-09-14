import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/gesendet_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/gesendet_liste.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der zweite Bereich des Postfachs: „Was ist heute rausgegangen?" (§4.3).
///
/// Die Zeichen der Vorgänge kommen aus dem app-weiten [VorgangCubit] und
/// werden hier **einmal** zu einer Tabelle verdichtet, statt sie in jeder
/// Zeile nachzuschlagen: Die Liste kann zweihundert Einträge lang sein, und
/// `findeZuReferenz` läuft je Aufruf über den ganzen Bestand.
class GesendetView extends StatelessWidget {
  const GesendetView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GesendetCubit, GesendetState>(
      builder: (context, state) {
        if (state.laedt && state.eintraege.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.fehler != null) return _fehler(context, state.fehler!);

        return GesendetListe(
          eintraege: state.eintraege,
          zeichen: {
            for (final vorgang in getIt<VorgangCubit>().state)
              vorgang.referenz.trim().toLowerCase(): vorgang.zeichen,
          },
        );
      },
    );
  }

  Widget _fehler(BuildContext context, String meldung) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              meldung,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<GesendetCubit>().laden(),
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
