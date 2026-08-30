import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Kompakter Hinweis über der Mandantenliste: wie viele gefundene Ordner noch
/// keinem Mandanten gehören und wie viele davon überhaupt als
/// Verkehrsunfallsache in Frage kommen.
///
/// Früher standen hier alle offenen Ordner als Kacheln. Bei rund 4000 im
/// Produktivbestand hieß das: die Mandantenliste beginnt viertausend Zeilen
/// weiter unten. Die Arbeit selbst passiert deshalb auf einer eigenen Seite,
/// hier steht nur noch der Zähler und der Weg dorthin.
class NichtZugeordneteSektion extends StatelessWidget {
  /// Noch zu entscheidende Ordner: weder zugeordnet noch als „ohne
  /// Mandantenbezug" vermerkt. Diese Zahl kann auf null gehen — das ist der
  /// Sinn des Stapels.
  final int offen;

  /// Davon die, die als Verkehrsunfallsache in Frage kommen.
  final int kandidaten;

  const NichtZugeordneteSektion({
    super.key,
    required this.offen,
    required this.kandidaten,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.rule_folder_outlined, size: 20, color: scheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$offen nicht zugeordnete Ordner',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$kandidaten davon kommen als Verkehrsunfallsache in Frage.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => _oeffnen(context),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Ordner zuordnen'),
          ),
        ],
      ),
    );
  }

  Future<void> _oeffnen(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    await context.router.push(const NichtZugeordneteOrdnerRoute());
    // Zurück aus dem Stapel: zugeordnet wurde im Register, am Dateisystem hat
    // sich nichts getan — der teure Scan bleibt stehen.
    bloc.add(const LoadMandantenUebersichtEvent(nurRegister: true));
  }
}
