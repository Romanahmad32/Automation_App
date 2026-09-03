import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Baut ein Auswahl-Widget aus dem geladenen Sachgebietskatalog — und setzt
/// den entschiedenen Fehlerfall (#70) an **einer** Stelle um: Liefert
/// `GET /api/Sachgebiete` nichts, erscheint statt der Auswahl ein
/// [FehlerHinweis] mit „Erneut versuchen", und die Auswahl bleibt aus.
/// Bewusst kein stilles Zurückfallen auf eine eingebaute Liste — eine
/// plausibel aussehende, unvollständige Auswahl ist genau die Fehlerklasse,
/// die der Katalog beseitigt (§7.1).
///
/// Hängt am app-weiten `@lazySingleton`-[SachgebietCubit] über `getIt`
/// (kein `BlocProvider` — der würde den Cubit beim Verlassen der Seite
/// schließen, gleiches Muster wie beim `VersichererCubit`).
class SachgebietKatalogBuilder extends StatelessWidget {
  /// Baut die eigentliche Auswahl aus den aktiven Katalogeinträgen.
  final Widget Function(BuildContext context, List<Sachgebiet> katalog) builder;

  const SachgebietKatalogBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<SachgebietCubit>();
    return BlocBuilder<SachgebietCubit, SachgebietKatalogStand>(
      bloc: cubit,
      builder: (context, stand) => switch (stand) {
        SachgebietKatalogLaedt() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(minHeight: 2),
        ),
        SachgebietKatalogGeladen(:final auswahl) => builder(context, auswahl),
        SachgebietKatalogFehler() => Row(
          children: [
            const Expanded(
              child: FehlerHinweis(
                nachricht:
                    'Der Sachgebietskatalog konnte nicht geladen werden — '
                    'die Auswahl ist so lange nicht möglich.',
              ),
            ),
            TextButton(
              onPressed: cubit.ladeErneut,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      },
    );
  }
}
