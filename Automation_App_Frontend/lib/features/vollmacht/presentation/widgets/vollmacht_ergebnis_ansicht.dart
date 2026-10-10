import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_abschluss.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_ergebnis_zeile.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Was nach dem Druck im Vollmacht-Dialog stehen bleibt (§4.11, #164).
///
/// Die App weiß nur, dass Word den Auftrag angenommen hat — nicht, ob ein
/// Blatt herauskam. Statt sich nach dem Druck sofort zu schließen, zeigt der
/// Dialog deshalb, wann und wohin übergeben wurde und ob der Vermerk sitzt,
/// und lässt an derselben Stelle nachsteuern: erneut drucken, in Word öffnen,
/// den Vermerk zurücknehmen. „Fertig" sitzt bei den Dialogknöpfen.
class VollmachtErgebnisAnsicht extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtErgebnisAnsicht({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final abschluss = stand.abschluss;
    if (abschluss == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cubit = context.read<VollmachtCubit>();
    final uhrzeit = deutscheUhrzeit(abschluss.zeitpunkt);
    final warnungen = abschluss.warnungen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        VollmachtErgebnisZeile(
          gelungen: true,
          text: switch (abschluss.weg) {
            VollmachtAbschlussWeg.gedruckt =>
              'Um $uhrzeit an ${abschluss.drucker ?? 'den Drucker'} übergeben',
            VollmachtAbschlussWeg.inWord =>
              'In Word gedruckt, um $uhrzeit bestätigt',
          },
        ),
        if (abschluss.vermerkt)
          const VollmachtErgebnisZeile(
            gelungen: true,
            text: 'Am Vorgang als gedruckt vermerkt',
          )
        else
          VollmachtErgebnisZeile(
            gelungen: false,
            text: 'Vermerk am Vorgang nicht gespeichert',
            aktion: TextButton(
              onPressed: cubit.vermerkeErneut,
              child: const Text('Erneut vermerken'),
            ),
          ),
        if (warnungen.isNotEmpty)
          VollmachtHinweis(
            icon: Icons.warning_amber_outlined,
            text:
                'In der Vorlage stehen Platzhalter, die die App nicht kennt: '
                '${warnungen.map((w) => '{{$w}}').join(', ')}.',
          ),
        const Divider(),
        Text('Kein Blatt gekommen?', style: theme.textTheme.titleSmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Erneut drucken'),
              onPressed: (stand.drucker?.kannDrucken ?? true)
                  ? cubit.druckeErneut
                  : null,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('In Word öffnen'),
              onPressed: cubit.oeffneInWordErneut,
            ),
            if (abschluss.vermerkt)
              TextButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('Vermerk zurücknehmen'),
                onPressed: cubit.nimmVermerkZurueck,
              ),
          ],
        ),
      ],
    );
  }
}
