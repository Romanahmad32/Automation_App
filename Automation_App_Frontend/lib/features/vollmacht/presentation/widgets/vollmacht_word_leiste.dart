import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Leiste zwischen Arbeitsfläche und Knöpfen, sobald der Dialog eine
/// Word-Fassung geöffnet hat (§4.11, #174): welche Datei, wann — und die
/// Frage, ob sie gedruckt ist. Die App weiß das nicht; deshalb fragt sie,
/// statt still zu vermerken.
///
/// „In Word öffnen" ist eine Nebenhandlung: Art, Felder und Vorschau
/// darüber bleiben bedienbar, und derselbe Knopf öffnet die Datei noch
/// einmal. Ließ sich Word nicht anstoßen, sagt die Leiste das und zeigt den
/// Weg über den Explorer.
class VollmachtWordLeiste extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtWordLeiste({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final fassung = stand.wordFassung;
    if (fassung == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cubit = context.read<VollmachtCubit>();
    final bedienbar = stand.phase == VollmachtPhase.eingabe;
    final uhrzeit = deutscheUhrzeit(fassung.zeitpunkt);

    return VollmachtHinweis(
      icon: Icons.description_outlined,
      // Geöffnet ist eine bloße Angabe; nicht geöffnet etwas, das der Anwalt
      // wissen muss — dann in der Hinweisfarbe.
      farbe: fassung.geoeffnet ? theme.colorScheme.onSurfaceVariant : null,
      text: fassung.geoeffnet
          ? 'In Word geöffnet ($uhrzeit) · ${fassung.dateiname}'
          : 'Die Vollmacht ist ausgefüllt, ließ sich aber nicht in Word '
                'öffnen · ${fassung.dateiname}',
      aktionen: [
        Text('Ist sie gedruckt?', style: theme.textTheme.bodyMedium),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.task_alt),
          label: const Text('Als gedruckt vermerken'),
          onPressed: bedienbar ? cubit.vermerkeAlsGedruckt : null,
        ),
        TextButton(
          onPressed: () => DateiOeffner.zeigeImOrdner(fassung.pfad),
          child: const Text('Im Explorer zeigen'),
        ),
      ],
    );
  }
}
